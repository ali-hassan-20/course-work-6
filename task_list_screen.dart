import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final CollectionReference tasksRef = FirebaseFirestore.instance.collection('tasks');

  void addTask(String taskName) async {
    if (taskName.isEmpty) return;
    await tasksRef.add({
      'name': taskName,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'subTasks': [],
    });
    _taskController.clear();
  }

  void toggleComplete(DocumentSnapshot taskDoc) {
    tasksRef.doc(taskDoc.id).update({
      'completed': !taskDoc['completed'],
    });
  }

  void deleteTask(String id) {
    tasksRef.doc(id).delete();
  }

  void addSubTask(String taskId, String timeBlock, List<String> subtasks) {
    tasksRef.doc(taskId).update({
      'subTasks': FieldValue.arrayUnion([
        {'time': timeBlock, 'details': subtasks}
      ])
    });
  }

  Widget buildSubTaskList(List subTasks) {
    return Column(
      children: subTasks.map<Widget>((item) {
        return ExpansionTile(
          title: Text("${item['time']}"),
          children: (item['details'] as List).map<Widget>((sub) => ListTile(title: Text(sub))).toList(),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Task Manager")),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(labelText: "Enter Task"),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => addTask(_taskController.text),
                )
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: tasksRef.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  var tasks = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      var task = tasks[index];
                      return Card(
                        elevation: 2,
                        child: ExpansionTile(
                          title: Row(
                            children: [
                              Checkbox(
                                value: task['completed'],
                                onChanged: (_) => toggleComplete(task),
                              ),
                              Expanded(child: Text(task['name'])),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => deleteTask(task.id),
                              ),
                            ],
                          ),
                          children: [
                            buildSubTaskList(task['subTasks'] ?? []),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: ElevatedButton(
                                child: const Text("Add Time Block"),
                                onPressed: () {
                                  _showSubTaskDialog(context, task.id);
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showSubTaskDialog(BuildContext context, String taskId) {
    final timeController = TextEditingController();
    final detailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Time Block & Subtasks"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: timeController,
                decoration: const InputDecoration(labelText: "Time Block (e.g., 9-10 AM)"),
              ),
              TextField(
                controller: detailController,
                decoration: const InputDecoration(labelText: "Subtasks (comma-separated)"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                final time = timeController.text;
                final tasks = detailController.text.split(',').map((e) => e.trim()).toList();
                addSubTask(taskId, time, tasks);
              },
              child: const Text("Add"),
            )
          ],
        );
      },
    );
  }
}
