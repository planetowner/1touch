import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class More extends StatelessWidget {
  const More({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "더 많은 옵션",
              style: TextStyle(color: Colors.white),
            ),
            IconButton(
                onPressed: () {
                  context.pop("/");
                },
                icon: Icon(
                  Icons.close,
                  color: Colors.white,
                )),
          ],
        ));
  }
}