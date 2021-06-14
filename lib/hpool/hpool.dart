import 'dart:convert';

import 'package:farmr_client/config.dart';
import 'package:farmr_client/farmer/wallet.dart';
import 'package:farmr_client/harvester/harvester.dart';
import 'package:farmr_client/farmer/farmer.dart';
import 'package:farmr_client/debug.dart' as Debug;
import 'package:farmr_client/hpool/api.dart';
import 'package:farmr_client/hpool/wallet.dart';

class HPool extends Farmer {
  String _authToken = '';

  @override
  String get status => "HPool";

  double _balance = -1.0;
  @override
  double get balance => _balance; //hides balance

  HPoolWallet _wallet = HPoolWallet(-1.0, -1.0);
  @override
  Wallet get wallet => _wallet;

  @override
  final ClientType type = ClientType.HPool;

  HPool({required Config config, required Debug.Log log, String version = ''})
      : super(config: config, log: log, version: version, hpool: true) {
    _authToken = config.hpoolAuthToken;
  }

  HPool.fromJson(String json) : super.fromJson(json) {
    var object = jsonDecode(json)[0];

    if (object['balance'] != null) _balance = object['balance'];

    if (object['walletBalance'] != null &&
        object['undistributedBalance'] != null)
      _wallet =
          HPoolWallet(object['walletBalance'], object['undistributedBalance']);
  }

  @override
  Map toJson() {
    Map farmerMap = (super.toJson());

    farmerMap.update("balance", (value) => _balance);
    farmerMap.update("walletBalance", (value) => _wallet.balance);

    farmerMap.addEntries({
      'undistributedBalance': _wallet.undistributedBalance, //wallet balance
    }.entries);

    return farmerMap;
  }

  //Adds harvester's plots into farm's plots
  void addHarvester(Harvester harvester) {
    super.addHarvester(harvester);
  }

  @override
  Future<void> init(String chiaConfigPath) async {
    //tries to parse hpool api
    HPoolApi api = HPoolApi();
    await api.init(_authToken);

    _balance = api.poolIncome; //farmed balance
    //wallet balance and unsettled income
    _wallet = HPoolWallet(api.balance, api.undistributedIncome);

    await super.init(chiaConfigPath);
  }
}