import 'package:flutter/material.dart';

class ContextMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isEnabled;
  final String? shortcut;

  const ContextMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isEnabled = true,
    this.shortcut,
  });
}

class ContextMenu extends StatelessWidget {
  final List<ContextMenuItem> items;
  final Offset position;

  const ContextMenu({
    Key? key,
    required this.items,
    required this.position,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 200,
            maxWidth: 300,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) {
              return _buildMenuItem(context, item);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, ContextMenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.isEnabled ? item.onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: item.isEnabled ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: item.isEnabled ? Colors.grey.shade800 : Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ),
              if (item.shortcut != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.shortcut!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// 右键菜单管理器
class ContextMenuManager {
  static OverlayEntry? _currentMenu;
  
  static void show({
    required BuildContext context,
    required List<ContextMenuItem> items,
    required Offset position,
  }) {
    // 隐藏当前菜单
    hide();
    
    // 创建新菜单
    _currentMenu = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 背景遮罩，点击关闭菜单
          Positioned.fill(
            child: GestureDetector(
              onTap: hide,
              child: Container(color: Colors.transparent),
            ),
          ),
          // 右键菜单
          ContextMenu(
            items: items,
            position: position,
          ),
        ],
      ),
    );
    
    // 显示菜单
    Overlay.of(context).insert(_currentMenu!);
  }
  
  static void hide() {
    _currentMenu?.remove();
    _currentMenu = null;
  }
}
