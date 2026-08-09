import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/helper_functions/error_dialog.dart';
import '../../../../core/helper_functions/file_picker_helper.dart';
import '../../data/repos/conversion_repo_impl.dart';
import '../../domain/entities/cow_list.dart';
import '../../domain/use_cases/convert_report_use_case.dart';
import '../manager/conversion_cubit/conversion_cubit.dart';
import 'widgets/cow_list_card.dart';
import 'widgets/report_convert_view.dart';

/// The single app shell. Owns the UI-local state (picked file, cow list) and
/// wires the [ConversionCubit] into the tree.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  late final ConversionCubit _conversionCubit;

  String? selectedHtmlPath;
  CowList? activeCowList;

  @override
  void initState() {
    super.initState();
    _conversionCubit = ConversionCubit(
      convertReportUseCase: ConvertReportUseCase(ConversionRepoImpl()),
    );
  }

  @override
  void dispose() {
    _conversionCubit.close();
    super.dispose();
  }

  Future<void> _selectHtml() async {
    final path = await pickHtmlFile();
    if (path != null) {
      setState(() => selectedHtmlPath = path);
    }
  }

  Future<void> _convert() async {
    final htmlPath = selectedHtmlPath;
    if (htmlPath == null) {
      showErrorDialog(context, 'Select an Alpro HTML report before converting.');
      return;
    }
    if (activeCowList == null) {
      showErrorDialog(context, 'Import a current cow list before converting.');
      return;
    }
    await _conversionCubit.convert(
      alproHtmlPath: htmlPath,
      cowList: activeCowList,
      outputXlsxPath: htmlPath, // placeholder; real save flow lands in US4
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _conversionCubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alfa → DairySense Converter'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CowListCard(cowList: activeCowList),
              const SizedBox(height: 16),
              ReportConvertView(
                selectedHtmlPath: selectedHtmlPath,
                onSelectHtml: _selectHtml,
                onConvert: _convert,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
