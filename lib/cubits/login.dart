import 'package:bloc/bloc.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:flutter_firebase_login/import.dart';

part 'login.g.dart';

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this.authenticationRepository)
      : assert(authenticationRepository != null),
        super(const LoginState());

  final AuthenticationRepository authenticationRepository;

  void emailChanged(String value) {
    final email = EmailInputModel.dirty(value);
    emit(state.copyWith(
      email: email,
      status: Formz.validate([email, state.password]),
    ));
  }

  void passwordChanged(String value) {
    final password = PasswordInputModel.dirty(value);
    emit(state.copyWith(
      password: password,
      status: Formz.validate([state.email, password]),
    ));
  }

  Future<void> logInWithCredentials() async {
    if (!state.status.isValidated) return;
    emit(state.copyWith(status: FormzStatus.submissionInProgress));
    try {
      await authenticationRepository.logInWithEmailAndPassword(
        email: state.email.value,
        password: state.password.value,
      );
      emit(state.copyWith(status: FormzStatus.submissionSuccess));
    } on Exception {
      emit(state.copyWith(status: FormzStatus.submissionFailure));
    }
  }

  Future<void> logInWithGoogle() async {
    emit(state.copyWith(status: FormzStatus.submissionInProgress));
    try {
      await authenticationRepository.logInWithGoogle();
      emit(state.copyWith(status: FormzStatus.submissionSuccess));
    } on Exception {
      emit(state.copyWith(status: FormzStatus.submissionFailure));
    } on NoSuchMethodError {
      emit(state.copyWith(status: FormzStatus.pure));
    }
  }
}

@CopyWith()
class LoginState extends Equatable {
  const LoginState({
    this.email = const EmailInputModel.pure(),
    this.password = const PasswordInputModel.pure(),
    this.status = FormzStatus.pure,
  });

  final EmailInputModel email;
  final PasswordInputModel password;
  // TODO: @CopyWithField(required: true)
  final FormzStatus status;

  @override
  List<Object> get props => [email, password, status];
}
