import 'dart:core';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'plot.dart';
import 'config.dart';

import 'harvester/plots.dart';
import 'harvester/diskspace.dart';

import 'debug.dart' as Debug;
import 'log/filter.dart';

class Harvester with HarvesterDiskSpace, HarvesterPlots {
  Config _config;
  List<String> _plotDests = []; //plot destination paths

  final String id = Uuid().v4();

  //Timestamp to when the farm was last parsed
  DateTime _lastUpdated;
  DateTime get lastUpdated => _lastUpdated;

  String _lastUpdatedString = "1971-01-01";
  String get lastUpdatedString => _lastUpdatedString;

  //Farmer or Harvester
  ClientType _type = ClientType.Harvester;
  ClientType get type => _type;

  List<Filter> filters = [];

  Map toJson() => {
        'plots': allPlots, //important
        'totalDiskSpace': totalDiskSpace,
        'freeDiskSpace': freeDiskSpace,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'lastUpdatedString': lastUpdatedString,
        'type': type.index,
        'filters': filters
      };

  Harvester(Config config, Debug.Log log) {
    _config = config;

    allPlots = config.cache.plots; //loads plots from cache

    _lastUpdated = DateTime.now();
    _lastUpdatedString = dateToString(_lastUpdated);

    filters = log.filters;
  }

  Harvester.fromJson(String json) {
    allPlots = [];

    var object = jsonDecode(json)[0];

    for (int i = 0; i < object['plots'].length; i++) {
      allPlots.add(Plot.fromJson(object['plots'][i]));
    }

    if (object['filters'] != null) {
      for (int i = 0; i < object['filters'].length; i++) {
        filters.add(Filter.fromJson(object['filters'][i]));
      }
    }

    if (object['totalDiskSpace'] != null && object['freeDiskSpace'] != null) {
      totalDiskSpace = object['totalDiskSpace'];
      freeDiskSpace = object['freeDiskSpace'];

      //if one of these values is 0 then it will assume that something went wrong in parsing disk space
      //or the client was outdated
      if (totalDiskSpace == 0 || freeDiskSpace == 0) supportDiskSpace = false;
    } else
      supportDiskSpace = false;

    _lastUpdated = DateTime.fromMillisecondsSinceEpoch(object['lastUpdated']);

    if (object['lastUpdatedString'] != null) _lastUpdatedString = object['lastUpdatedString'];

    _type = ClientType.values[object['type']];
  }

  Future<void> init(String chiaConfigPath) async {
    //LOADS CHIA CONFIG FILE AND PARSES PLOT DIRECTORIES
    _plotDests = listPlotDest(chiaConfigPath);

    await listPlots(_plotDests, _config);

    filterDuplicates(); //removes duplicate ids

    _lastUpdated = DateTime.now();

    await getDiskSpace(_plotDests);
  }

  //clears plots ids before sending info to server
  //clears filters timestamps before sending info to server
  void clearIDs() {
    for (int i = 0; i < allPlots.length; i++) allPlots[i].clearID();
    for (int i = 0; i < filters.length; i++) filters[i].clearTimestamp();

    filters
        .shuffle(); //shuffles filters so that harvester can't be tracked by answered challenges time
  }
}
