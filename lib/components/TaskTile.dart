import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/task/edit_task.dart';
import 'package:vikunja_app/utils/misc.dart';

class TaskTile extends StatefulWidget {
  final Task task;
  final Function onEdit;
  final bool showInfo;

  const TaskTile(
      {Key key, @required this.task, this.onEdit, this.showInfo = false})
      : assert(task != null),
        super(key: key);
/*
  @override
  TaskTileState createState() {
    return new TaskTileState(this.task, this.loading);
  }

 */
@override
  TaskTileState createState() => TaskTileState(this.task);
}

class TaskTileState extends State<TaskTile> {
  Task _currentTask;

  TaskTileState(this._currentTask)
      : assert(_currentTask != null);

  @override
  Widget build(BuildContext context) {
    Duration durationUntilDue = _currentTask.due.difference(DateTime.now());
    if (_currentTask.loading) {
      return ListTile(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: SizedBox(
              height: Checkbox.width,
              width: Checkbox.width,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
              )),
        ),
        title: Text(_currentTask.title),
        subtitle:
            _currentTask.description == null || _currentTask.description.isEmpty
                ? null
                : Text(_currentTask.description),
        trailing: IconButton(
            icon: Icon(Icons.settings), onPressed: () {  },
            ),
      );
    }
    return CheckboxListTile(
      title: widget.showInfo ?
          RichText(
            text: TextSpan(
              text: null,
              children: <TextSpan> [
                TextSpan(text: widget.task.list.title+" - ", style: TextStyle(color: Colors.grey)),
                TextSpan(text: widget.task.title),
              ]
            )
          ) : Text(_currentTask.title),
      controlAffinity: ListTileControlAffinity.leading,
      value: _currentTask.done ?? false,
      subtitle: widget.showInfo && _currentTask.due.year > 2 ?
          Text("Due in " + durationToHumanReadable(durationUntilDue),style: TextStyle(color: durationUntilDue.isNegative ? Colors.red : null),)
          : _currentTask.description == null || _currentTask.description.isEmpty
              ? null
              : Text(_currentTask.description),
      secondary:
          IconButton(icon: Icon(Icons.settings), onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => TaskEditPage(
                      task: _currentTask,
                    ))).whenComplete(() {
                      widget.onEdit();
                    });
          }),
      onChanged: _change,
    );
  }

  void _change(bool value) async {
    setState(() {
      this._currentTask.loading = true;
    });
    Task newTask = await _updateTask(_currentTask, value);
    setState(() {
      this._currentTask = newTask;
      this._currentTask.loading = false;
    });
    widget.onEdit();
  }

  Future<Task> _updateTask(Task task, bool checked) {
    // TODO use copyFrom
    return VikunjaGlobal.of(context).taskService.update(Task(
          id: task.id,
          done: checked,
          title: task.title,
          description: task.description,
          owner: task.owner,
          due: task.due
        ));
  }
}

typedef Future<void> TaskChanged(Task task, bool newValue);
