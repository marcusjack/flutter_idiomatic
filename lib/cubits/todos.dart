import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:flutter_firebase_login/import.dart';

part 'todos.g.dart';

class TodosCubit extends Cubit<TodosState> {
  TodosCubit(this._repository)
      : assert(_repository != null),
        super(const TodosState()) {
    _fetchNewNotificationSubscription =
        _repository.fetchNewTodoNotification.listen(fetchNewNotification);
  }

  final DatabaseRepository _repository;
  StreamSubscription<int> _fetchNewNotificationSubscription;
  bool isStartedSubscription = false;

  @override
  Future<void> close() {
    _fetchNewNotificationSubscription?.cancel();
    return super.close();
  }

  void fetchNewNotification(int id) {
    if (!isStartedSubscription) {
      isStartedSubscription = true;
      return;
    }
    emit(state.copyWith(newId: id));
  }

  Future<bool> load({
    bool isRefresh = false,
    TodosIndicator indicator,
  }) async {
    const kLimit = 10;
    emit(state.copyWith(
      status: TodosStatus.busy,
      indicator: indicator,
    ));
    try {
      final items = await _repository.readTodos(
        createdAt: isRefresh ? null : state.nextDateTime,
        limit: kLimit + 1,
      );
      var hasMore = false;
      DateTime nextDateTime;
      if (items.length == kLimit + 1) {
        hasMore = true;
        final lastItem = items.removeLast();
        nextDateTime = lastItem.createdAt;
      }
      if (isRefresh) {
        emit(const TodosState());
        await Future.delayed(const Duration(milliseconds: 300));
      }
      emit(state.copyWith(
        items: [...state.items, ...items],
        hasMore: hasMore,
        nextDateTime: nextDateTime,
      ));
    } catch (error) {
      return false;
    } finally {
      emit(state.copyWith(
        status: TodosStatus.ready,
        indicator: TodosIndicator.loadMore,
      ));
    }
    return true;
  }

  Future<bool> remove(int id) async {
    emit(state.copyWith(
      items: [...state.items..removeWhere((TodoModel item) => item.id == id)],
    ));
    try {
      final deletedId = await _repository.deleteTodo(id);
      if (deletedId != id) {
        throw 'Can not remove todo $id';
      }
    } catch (error) {
      return false;
    }
    return true;
  }

  Future<bool> add(String title) async {
    final titleInput = TitleInputModel.dirty(title);
    final status = Formz.validate([titleInput]);
    if (status.isInvalid) {
      throw titleInput.error;
    }
    emit(state.copyWith(isSubmitMode: true));
    try {
      final item = await _repository.createTodo(titleInput.value);
      emit(state.copyWith(
        items: [item, ...state.items],
      ));
    } catch (error) {
      return false;
    } finally {
      emit(state.copyWith(isSubmitMode: false));
    }
    return true;
  }
}

enum TodosStatus { initial, busy, ready }
enum TodosIndicator { initial, start, refreshIndicator, loadNew, loadMore }

@CopyWith()
class TodosState extends Equatable {
  const TodosState({
    this.items = const [],
    this.status = TodosStatus.initial,
    this.indicator = TodosIndicator.initial,
    this.hasMore = false,
    this.nextDateTime,
    this.newId,
    this.isSubmitMode = false,
  });

  final List<TodoModel> items;
  final TodosStatus status;
  final TodosIndicator indicator;
  final DateTime nextDateTime;
  final bool hasMore;
  final int newId;
  final bool isSubmitMode;

  bool get hasReallyNewId =>
      newId != null &&
      items.indexWhere((TodoModel item) => item.id == newId) == -1;

  @override
  List<Object> get props => [
        items,
        status,
        indicator,
        hasMore,
        nextDateTime,
        newId,
        isSubmitMode,
      ];
}
