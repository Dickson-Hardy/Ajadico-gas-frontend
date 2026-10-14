import 'package:flutter/material.dart';

import 'ajadico_logo.dart';

/// Persistent, responsive navigation around the existing operational screens.
class WorkspaceDestination {
  const WorkspaceDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.group,
    this.count = 0,
  });

  final String id;
  final String label;
  final IconData icon;
  final String group;
  final int count;
}

class OperationsWorkspace extends StatefulWidget {
  const OperationsWorkspace({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    required this.userName,
    required this.roleLabel,
    required this.stationName,
    required this.onSignOut,
    required this.child,
    required this.status,
    this.stationPicker,
    this.notifications,
    this.onToggleTheme,
  });

  final List<WorkspaceDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final String userName;
  final String roleLabel;
  final String stationName;
  final VoidCallback onSignOut;
  final VoidCallback? onToggleTheme;
  final Widget? stationPicker;
  final Widget? notifications;
  final Widget status;
  final Widget child;

  @override
  State<OperationsWorkspace> createState() => _OperationsWorkspaceState();
}

class _OperationsWorkspaceState extends State<OperationsWorkspace> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _navigationScroll = ScrollController();

  @override
  void dispose() {
    _navigationScroll.dispose();
    super.dispose();
  }

  Widget _navigation({required bool drawer}) {
    final groups = widget.destinations.map((d) => d.group).toSet();
    return Material(
      color: const Color(0xFF102C2B),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
              child: Row(
                children: [
                  const AjadicoLogo.emblem(size: 34),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AJADICO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.8)),
                        SizedBox(height: 3),
                        Text('Station operations',
                            style: TextStyle(
                                color: Color(0xFFA7BEBB), fontSize: 11)),
                      ],
                    ),
                  ),
                  if (drawer)
                    IconButton(
                      tooltip: 'Close navigation',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2B4643), height: 1),
            Expanded(
              child: Scrollbar(
                controller: _navigationScroll,
                thumbVisibility: true,
                child: ListView(
                  controller: _navigationScroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  children: [
                    for (final group in groups) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 20, 12, 10),
                        child: Text(group.toUpperCase(),
                            style: const TextStyle(
                                color: Color(0xFF96AFAB),
                                fontSize: 10,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600)),
                      ),
                      for (final item
                          in widget.destinations.where((d) => d.group == group))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: ListTile(
                            selected: item.id == widget.selectedId,
                            selectedTileColor: const Color(0xFF24534C),
                            selectedColor: Colors.white,
                            textColor: const Color(0xFFC8D7D4),
                            iconColor: const Color(0xFFAEC5BF),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            minLeadingWidth: 20,
                            minTileHeight: 48,
                            horizontalTitleGap: 12,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            leading: Icon(item.icon, size: 19),
                            title: Text(item.label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: item.id == widget.selectedId
                                        ? FontWeight.w600
                                        : FontWeight.w400)),
                            trailing: item.count > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF365F56),
                                        borderRadius: BorderRadius.circular(4)),
                                    child: Text('${item.count}',
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 11)),
                                  )
                                : null,
                            onTap: () {
                              if (drawer) Navigator.pop(context);
                              widget.onSelect(item.id);
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(color: Color(0xFF2B4643), height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF294943),
                    child: Text(
                        widget.userName.trim().isEmpty
                            ? '?'
                            : widget.userName.trim()[0].toUpperCase(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(widget.roleLabel,
                            style: const TextStyle(
                                color: Color(0xFFA7BEBB), fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: widget.onSignOut,
                      tooltip: 'Sign out',
                      icon: const Icon(Icons.logout,
                          color: Color(0xFFB5C9C4), size: 18)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1100;
        final compact = constraints.maxWidth < 650;
        return Scaffold(
          key: _scaffoldKey,
          drawer: wide
              ? null
              : Drawer(width: 276, child: _navigation(drawer: true)),
          body: Row(
            children: [
              if (wide) SizedBox(width: 246, child: _navigation(drawer: false)),
              Expanded(
                child: Column(
                  children: [
                    Material(
                      color: colors.surface,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          height: 64,
                          padding: EdgeInsets.symmetric(
                              horizontal: compact ? 8 : 24),
                          decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: colors.outlineVariant))),
                          child: Row(
                            children: [
                              if (!wide) ...[
                                IconButton(
                                    tooltip: 'Open navigation',
                                    onPressed: () =>
                                        _scaffoldKey.currentState?.openDrawer(),
                                    icon: const Icon(Icons.menu)),
                                const SizedBox(width: 4),
                              ],
                              if (!compact) ...[
                                Icon(Icons.location_on_outlined,
                                    size: 18, color: colors.onSurfaceVariant),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                  child: widget.stationPicker ??
                                      Text(widget.stationName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600))),
                              const SizedBox(width: 8),
                              if (!compact) ...[
                                widget.status,
                                const SizedBox(width: 18)
                              ],
                              if (widget.notifications != null)
                                widget.notifications!,
                              if (widget.onToggleTheme != null)
                                IconButton(
                                    tooltip: 'Change appearance',
                                    onPressed: widget.onToggleTheme,
                                    icon: const Icon(
                                        Icons.brightness_6_outlined,
                                        size: 19)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: widget.child),
                    if (compact)
                      Material(
                          color: colors.surface,
                          child: SafeArea(
                              top: false,
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: widget.status))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class WorkspaceMetric extends StatelessWidget {
  const WorkspaceMetric(
      {super.key,
      required this.label,
      required this.value,
      this.detail,
      this.color});
  final String label;
  final String value;
  final String? detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: color ?? scheme.onSurface))),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!,
                style: TextStyle(
                    fontSize: 11, height: 1.4, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class WorkspaceSection extends StatelessWidget {
  const WorkspaceSection(
      {super.key,
      required this.title,
      required this.child,
      this.subtitle,
      this.action});
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: 12, color: colors.onSurfaceVariant))
                      ],
                    ])),
                if (action != null) ...[const SizedBox(width: 8), action!],
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          child,
        ],
      ),
    );
  }
}
