part of 'conversion_cubit.dart';

abstract class ConversionState {}

class ConversionInitial extends ConversionState {}

class ConversionLoading extends ConversionState {}

class ConversionSuccess extends ConversionState {
  final ConversionResult conversionResult;

  ConversionSuccess(this.conversionResult);
}

class ConversionFailure extends ConversionState {
  final String errMessage;

  ConversionFailure(this.errMessage);
}
