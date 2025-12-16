import 'package:flutter/material.dart';

/// A widget that displays a context menu for browser tabs with actions like
/// close, duplicate, and close multiple tabs.
class TabContextMenu {
  /// Shows the tab context menu at the specified position.
  /// 
  /// Returns the selected menu action as a string, or null if no action was selected.
  static Future<String?> show({
    required BuildContext context,
    required Offset position,
    required int tabIndex,
    required int totalTabs,
  }) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    return showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: 'close',
          child: Row(
            children: [
              Icon(Icons.close, size: 18),
              SizedBox(width: 8),
              Text('Close'),
            ],
          ),
        ),
        if (totalTabs > 1)
          const PopupMenuItem(
            value: 'close_others',
            child: Row(
              children: [
                Icon(Icons.tab, size: 18),
                SizedBox(width: 8),
                Text('Close Others'),
              ],
            ),
          ),
        if (tabIndex > 0)
          const PopupMenuItem(
            value: 'close_left',
            child: Row(
              children: [
                Icon(Icons.arrow_back, size: 18),
                SizedBox(width: 8),
                Text('Close to Left'),
              ],
            ),
          ),
        if (tabIndex < totalTabs - 1)
          const PopupMenuItem(
            value: 'close_right',
            child: Row(
              children: [
                Icon(Icons.arrow_forward, size: 18),
                SizedBox(width: 8),
                Text('Close to Right'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(Icons.content_copy, size: 18),
              SizedBox(width: 8),
              Text('Duplicate'),
            ],
          ),
        ),
      ],
    );
  }
}
