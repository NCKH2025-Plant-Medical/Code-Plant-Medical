import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class SearchTextField extends StatelessWidget {
  final String hintText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool autoFocus;
  final bool readOnly;
  final String heroTag;
  final TextEditingController? controller;

  const SearchTextField({
    super.key,
    required this.hintText,
    this.onTap,
    this.onChanged,
    this.autoFocus = false,
    this.readOnly = true,
    this.heroTag = 'search_bar',
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag,
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            return DefaultTextStyle(
              style: DefaultTextStyle.of(toHeroContext).style,
              child: toHeroContext.widget,
            );
          },
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.09),
                blurRadius: 11,
                spreadRadius: 7,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: readOnly ? onTap : null,
              child: IgnorePointer(
                // readOnly = true (Home): chặn nhập, chỉ xử lý tap
                // readOnly = false (Search): cho phép gõ phím
                ignoring: readOnly,
                child: TextField(
                  controller: controller,
                  autofocus: autoFocus,
                  onChanged: onChanged,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.transparent,
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 20.0, right: 12.0),
                      child: Icon(
                        CupertinoIcons.search,
                        color: Color(0xFF9CA3AF),
                        size: 22,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
