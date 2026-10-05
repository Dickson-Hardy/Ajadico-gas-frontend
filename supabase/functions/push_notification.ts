// =============================================================================
// AJADICO FILLING STATION MANAGEMENT SYSTEM
// Supabase Edge Function: Push Notifications Engine (BRD v3 §5.5, §2.8, §4.6)
// Dispatches real-time background push notifications to Managers and Directors
// via Firebase Cloud Messaging (FCM) based on Supabase Database Webhooks.
// =============================================================================

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: Record<string, any>;
  old_record?: Record<string, any>;
}

interface PushMessage {
  title: string;
  body: string;
  topic?: string;
  targetRole?: "director" | "manager" | "cashier" | "attendant" | "all";
  stationId?: string;
  data: Record<string, string>;
}

const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY") || "";
const FCM_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") || "ajadico-energy";

Deno.serve(async (req: Request) => {
  // CORS headers
  const headers = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response(JSON.stringify({ ok: true }), { headers, status: 200 });
  }

  try {
    const payload: WebhookPayload = await req.json();
    console.log(`[Webhook Received] Table: ${payload.table}, Action: ${payload.type}`);

    const pushMessage = evaluateNotificationEvent(payload);

    if (!pushMessage) {
      return new Response(
        JSON.stringify({ status: "ignored", reason: "No notification trigger for this event" }),
        { headers, status: 200 }
      );
    }

    const dispatchResult = await sendFcmPushNotification(pushMessage);

    return new Response(
      JSON.stringify({
        status: "success",
        event: pushMessage.title,
        dispatch: dispatchResult,
      }),
      { headers, status: 200 }
    );
  } catch (err: any) {
    console.error("[Push Notification Error]", err);
    return new Response(
      JSON.stringify({ status: "error", error: err.message }),
      { headers, status: 500 }
    );
  }
});

/**
 * Evaluates database change and maps to high-priority operational alert
 */
function evaluateNotificationEvent(payload: WebhookPayload): PushMessage | null {
  const { table, type, record, old_record } = payload;

  // 1. Shift Remittance Submission & Verification (§4.5, §4.6)
  if (table === "remittances" || table === "shifts") {
    if (type === "INSERT") {
      return {
        title: "New Shift Remittance Submitted",
        body: `Attendant shift remittance submitted. Awaiting cashier verification.`,
        targetRole: "cashier",
        topic: "station_cashiers",
        stationId: record.station_id,
        data: {
          screen: "09 Verify Submission",
          shiftId: record.id || "",
          type: "shift_submitted",
        },
      };
    }

    if (type === "UPDATE" && record.status === "Flagged Unresolved") {
      const variance = record.declared_difference || 0;
      return {
        title: "CRITICAL: Shortage Flagged on Shift",
        body: `Cashier flagged shortfall of ₦${Math.abs(variance).toLocaleString()}. Awaiting Director salary adjustment review.`,
        targetRole: "director",
        topic: "directors",
        stationId: record.station_id,
        data: {
          screen: "19 Salary Deductions",
          shiftId: record.id || "",
          variance: String(variance),
          type: "shortage_flagged",
        },
      };
    }
  }

  // 2. Retail Fuel Price Change Directive (§2.8, §2.9)
  if (table === "fuel_prices" && type === "INSERT") {
    return {
      title: "PRICE CHANGE DIRECTIVE",
      body: `Fuel price updated to ₦${record.price_per_litre}/L by Director. All 5 branches must adjust nozzles immediately.`,
      targetRole: "all",
      topic: "all_stations",
      stationId: record.station_id,
      data: {
        screen: "18 Retail Fuel Prices",
        productId: record.product_id || "",
        newPrice: String(record.price_per_litre),
        type: "price_change",
      },
    };
  }

  // 3. Tanker Fuel Delivery Discharged (§3.1, §3.4)
  if (table === "fuel_deliveries" && type === "INSERT") {
    return {
      title: "Tanker Fuel Delivery Discharged",
      body: `${record.received_litres || 0}L received from ${record.supplier || "Supplier"} (Waybill: ${record.waybill_number || "N/A"}).`,
      targetRole: "director",
      topic: "directors",
      stationId: record.station_id,
      data: {
        screen: "13 Fuel Delivery (Waybill)",
        deliveryId: record.id || "",
        type: "fuel_delivery",
      },
    };
  }

  // 4. Physical Tank Dip Stock Deficit (§3.2, §3.3)
  if (table === "tank_dips" && type === "INSERT") {
    const variance = Number(record.variance_litres || 0);
    if (variance < -50) {
      return {
        title: "WARNING: Tank Physical Dip Deficit",
        body: `Tank physical dip differs by ${variance.toFixed(1)}L from calculated book stock.`,
        targetRole: "manager",
        topic: "managers",
        stationId: record.station_id,
        data: {
          screen: "12 Tank Dip Audit",
          tankId: record.tank_id || "",
          variance: String(variance),
          type: "dip_deficit",
        },
      };
    }
  }

  // 5. Commercial Bank Deposit Confirmation (§4.3, §5.5)
  if (table === "bank_deposits" || table === "daily_cash_counts") {
    if (type === "UPDATE" && record.is_confirmed && !old_record?.is_confirmed) {
      return {
        title: "Bank Deposit Confirmed",
        body: `Director confirmed commercial bank credit alert for deposit of ₦${(record.amount || 0).toLocaleString()}.`,
        targetRole: "cashier",
        topic: "station_cashiers",
        stationId: record.station_id,
        data: {
          screen: "20 Bank Deposits",
          depositId: record.id || "",
          type: "deposit_confirmed",
        },
      };
    }
  }

  // 6. Attendant Salary Deduction Decision (§4.6)
  if (table === "attendant_salary_adjustments" && type === "UPDATE") {
    return {
      title: "Salary Deduction Status Updated",
      body: `Director updated status: ${record.status} for ${record.attendant_name || "attendant"}.`,
      targetRole: "manager",
      topic: "managers",
      stationId: record.station_id,
      data: {
        screen: "19 Salary Deductions",
        adjustmentId: record.id || "",
        type: "salary_decision",
      },
    };
  }

  return null;
}

/**
 * Sends FCM push notification via Google Firebase Cloud Messaging HTTP endpoint
 */
async function sendFcmPushNotification(msg: PushMessage): Promise<any> {
  if (!FCM_SERVER_KEY) {
    console.log("[FCM Mock Dispatch] (No FCM_SERVER_KEY configured in Supabase secrets):", msg);
    return {
      dispatched: false,
      simulated: true,
      reason: "FCM_SERVER_KEY not set in Supabase vault. Push payload generated successfully.",
      payload: msg,
    };
  }

  const topicName = msg.topic || "all_stations";
  const fcmPayload = {
    to: `/topics/${topicName}`,
    priority: "high",
    notification: {
      title: msg.title,
      body: msg.body,
      sound: "default",
      badge: "1",
    },
    data: {
      ...msg.data,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      stationId: msg.stationId || "",
    },
  };

  const response = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify(fcmPayload),
  });

  const responseData = await response.json();
  console.log("[FCM Sent]", responseData);
  return responseData;
}
