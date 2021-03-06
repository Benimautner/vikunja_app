import 'dart:async';

import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/service.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/service/services.dart';

class TaskAPIService extends APIService implements TaskService {
  TaskAPIService(Client client) : super(client);

  @override
  Future<Task> add(int listId, Task task) {
    return client
        .put('/lists/$listId', body: task.toJSON())
        .then((map) => Task.fromJson(map));
  }

  @override
  Future<List<Task>> get(int listId) {
    return client.get('/list/$listId/tasks');
  }

  @override
  Future delete(int taskId) {
    return client.delete('/tasks/$taskId');
  }

  @override
  Future<Task> update(Task task) {
    return client
        .post('/tasks/${task.id}', body: task.toJSON())
        .then((map) => Task.fromJson(map));
  }
  
  @override
  Future<List<Task>> getAll() {
    return client
        .get('/tasks/all')
        .then((value) => value.map<Task>((taskJson) => Task.fromJson(taskJson)).toList());
  }

  @override
  Future<List<Task>> getByOptions(TaskServiceOptions options) {
    String optionString = options.getOptions();
    return client
        .get('/tasks/all?$optionString')
        .then((value) {
          return  value.map<Task>((taskJson) => Task.fromJson(taskJson)).toList();
    });
  }

}
