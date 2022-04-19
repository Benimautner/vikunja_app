//import 'dart:math';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/api/client.dart';
import 'package:vikunja_app/api/list_implementation.dart';
import 'package:vikunja_app/api/namespace_implementation.dart';
import 'package:vikunja_app/api/task_implementation.dart';
import 'package:vikunja_app/api/user_implementation.dart';
import 'package:vikunja_app/managers/notifications.dart';
import 'package:vikunja_app/managers/user.dart';
import 'package:vikunja_app/models/user.dart';
import 'package:vikunja_app/service/services.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class VikunjaGlobal extends StatefulWidget {
  final Widget child;
  final Widget login;

  VikunjaGlobal({this.child, this.login});

  @override
  VikunjaGlobalState createState() => VikunjaGlobalState();

  static VikunjaGlobalState of(BuildContext context) {
    var widget = context.dependOnInheritedWidgetOfExactType<_VikunjaGlobalInherited>();
    return widget.data;
  }
}

class VikunjaGlobalState extends State<VikunjaGlobal> {
  final FlutterSecureStorage _storage = new FlutterSecureStorage();

  User _currentUser;
  Client _client;
  bool _loading = true;

  User get currentUser => _currentUser;

  Client get client => _client;

  UserManager get userManager => new UserManager(_storage);

  UserService newUserService(base) => new UserAPIService(Client(null, base));

  NamespaceService get namespaceService => new NamespaceAPIService(client);

  TaskService get taskService => new TaskAPIService(client);

  ListService get listService => new ListAPIService(client, _storage);

  FlutterLocalNotificationsPlugin get notificationsPlugin => new FlutterLocalNotificationsPlugin();

  TaskServiceOptions get taskServiceOptions => new TaskServiceOptions();

  NotificationClass get notifications => new NotificationClass();

  NotificationAppLaunchDetails notifLaunch;


  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    tz.initializeTimeZones();
    notificationInitializer();
  }

  void changeUser(User newUser, {String token, String base}) async {
    setState(() {
      _loading = true;
    });
    if (token == null) {
      token = await _storage.read(key: newUser.id.toString());
    } else {
      // Write new token to secure storage
      await _storage.write(key: newUser.id.toString(), value: token);
    }
    if (base == null) {
      base = await _storage.read(key: "${newUser.id.toString()}_base");
    } else {
      // Write new base to secure storage
      await _storage.write(key: "${newUser.id.toString()}_base", value: base);
    }
    // Set current user in storage
    await _storage.write(key: 'currentUser', value: newUser.id.toString());
    setState(() {
      _currentUser = newUser;
      _client = Client(token, base);
      _loading = false;
    });
  }

  void notificationInitializer() async {
    notifLaunch = await notificationsPlugin.getNotificationAppLaunchDetails();
    await notifications.initNotifications(notificationsPlugin);
    requestIOSPermissions(notificationsPlugin);

  }

  void scheduleDueNotifications() {
    notificationsPlugin.cancelAll().then((value) {
      taskService.getAll().then((value) =>
          value.forEach((task) {
            if(task.reminders != null)
              task.reminders.forEach((reminder) {
                scheduleNotification("This is your reminder for '" + task.title + "'", task.description, notificationsPlugin, reminder);
              });
            if(task.due != null)
              scheduleNotification("The task '" + task.title + "' is due.", task.description, notificationsPlugin, task.due);
          })
      );
    });
  }


  void logoutUser(BuildContext context) {
    _storage.deleteAll().then((_) {
      Navigator.pop(context);
      setState(() {
        _client = null;
        _currentUser = null;
      });
    }).catchError((err) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('An error occured while logging out!'),
      ));
    });
  }

  void _loadCurrentUser() async {
    var currentUser = await _storage.read(key: 'currentUser');
    if (currentUser == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    var token = await _storage.read(key: currentUser);
    var base = await _storage.read(key: '${currentUser}_base');
    if (token == null || base == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    var client = Client(token, base);
    var loadedCurrentUser;
    try {
      loadedCurrentUser = await UserAPIService(client).getCurrentUser();
    } on ApiException catch (e) {
      if (e.errorCode ~/ 100 == 4) {
        setState(() {
          _client = null;
          _currentUser = null;
          _loading = false;
        });
        return;
      }
      loadedCurrentUser = User(int.tryParse(currentUser), "", "");
    } catch (otherExceptions) {
      loadedCurrentUser = User(int.tryParse(currentUser), "", "");
    }
    setState(() {
      _client = client;
      _currentUser = loadedCurrentUser;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return new Center(child: new CircularProgressIndicator());
    }
    if(client != null) {
      scheduleDueNotifications();
    }
    return new _VikunjaGlobalInherited(
      data: this,
      child: client == null ? widget.login : widget.child,
    );
  }
}

class _VikunjaGlobalInherited extends InheritedWidget {
  final VikunjaGlobalState data;

  _VikunjaGlobalInherited({Key key, this.data, Widget child})
      : super(key: key, child: child);

  @override
  bool updateShouldNotify(_VikunjaGlobalInherited oldWidget) {
    return (data.currentUser != null &&
            data.currentUser.id != oldWidget.data.currentUser.id) ||
        data.client != oldWidget.data.client;
  }
}
