library repo;

import 'package:common/base/mvvm/repo/api_repository.dart';
import 'package:common/base/mvvm/repo/dio_proxy.dart';
import 'package:common/common/network/dio_client.dart';
import '../http/sample_dio_proxy.dart';

import '../repository/api.dart';

// repos
part '../repository/menu_repo.dart';

// models

/// 业务层的base请求仓库
class BaseRepo extends ApiRepository {
  @override
  DioProxy proxy = SampleDioProxy.get();
}
