import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings_model.dart';
import '../models/file_transfer_model.dart';
import '../core/locations.dart';

// 国家代码到名称的映射
final Map<String, String> _countryNames = {
  'ALL': '所有国家',
  'US': '美国',
  'CN': '中国',
  'IN': '印度',
  'FR': '法国',
  'DE': '德国',
  'BR': '巴西',
  'RU': '俄罗斯',
  'JP': '日本',
  'KR': '韩国',
};

class CountrySelector extends StatefulWidget {
  final ValueChanged<String> onCountrySelected;
  final ValueChanged<List<String>> onCountryListLoaded;

  const CountrySelector({
    Key? key,
    required this.onCountrySelected,
    required this.onCountryListLoaded,
  }) : super(key: key);

  @override
  _CountrySelectorState createState() => _CountrySelectorState();
}

class _CountrySelectorState extends State<CountrySelector> {
  String _selectedCountry = 'ALL'; // 默认选择所有国家
  List<String> _countryList = [];

  @override
  void initState() {
    super.initState();
    _loadCountries();

    // 添加延迟重新加载，以防国家列表在初始化后才可用
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _countryList.isEmpty) {
        debugPrint('延迟重新加载国家列表');
        _loadCountries();
      }
    });
  }

  Future<void> _loadCountries() async {
    // 获取国家列表
    final countryList = await _fetchCountryList();

    if (mounted) {
      setState(() {
        _countryList = countryList;

        // 如果之前没有选择国家或选择的国家不在列表中，设置为第一个国家
        if (_countryList.isNotEmpty &&
            (!_countryList.contains(_selectedCountry) || _selectedCountry == 'ALL')) {
          _selectedCountry = _countryList[0];
        }
      });

      // 通知父组件国家列表已加载
      widget.onCountryListLoaded(_countryList);

      // 如果有国家被选中，通知父组件
      if (_countryList.isNotEmpty) {
        widget.onCountrySelected(_selectedCountry);
      }
    }
  }

  Future<List<String>> _fetchCountryList() async {
    try {
      // 从Provider获取FileTransferModel，然后获取国家列表
      final model = Provider.of<FileTransferModel>(context, listen: false);
      // 如果列表为空，返回默认列表
      if (model.countryList.isEmpty) {
        return ['ALL', 'US', 'CN', 'IN', 'FR', 'DE', 'BR', 'RU', 'JP', 'KR'];
      }
      // 确保ALL选项在列表中
      if (!model.countryList.contains('ALL')) {
        return ['ALL', ...model.countryList];
      }
      return model.countryList;
    } catch (e) {
      debugPrint('获取国家列表失败: $e');
      return ['ALL'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsModel>(context);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[300] ?? Colors.grey, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedCountry,
            isExpanded: true,
            hint: Text('选择国家'),
            items: _countryList.map((country) {
              return DropdownMenuItem<String>(
                value: country,
                child: Text(_countryNames[country] ?? country, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null && newValue != _selectedCountry) {
                setState(() {
                  _selectedCountry = newValue;
                });

                // 更新设置中的选中国家
                if (newValue == 'ALL') {
                  settings.clearSelectedCountries();
                } else {
                  settings.setSelectedCountries([newValue]);
                }

                // 通知父组件国家已更改
                widget.onCountrySelected(_selectedCountry);
              }
            },
          ),
        ),
      ),
    );
  }
}
