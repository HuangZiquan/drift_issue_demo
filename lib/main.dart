import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:executor/executor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lorem/flutter_lorem.dart';

import 'database/database.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    openDB();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Center(
        child: TextButton(
          onPressed: () async {
            final executor = Executor(concurrency: Platform.numberOfProcessors);
            for (var i in List<int>.generate(1000, (i) => i)) {
              executor.scheduleTask(() async {
                await compute<Map, void>(syncRoomMessages, {
                  'driftIsolate': driftIsolate,
                });
                print(i);
              });
            }
            await executor.join(withWaiting: true);
            await executor.close();
          },
          child: const Text("RUN"),
        ),
      ),
    );
  }
}

Future<void> syncRoomMessages(Map map) async {
  final driftIsolate = map['driftIsolate'] as DriftIsolate;

  final connection = await driftIsolate.connect();
  final db = AppDatabase.connect(connection);

  String text = lorem(paragraphs: 2, words: 60);
  await db.sentences.insertOne(SentencesCompanion.insert(
    description: text,
  ));

  await db.close();
}
