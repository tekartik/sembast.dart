/// Copied from package cv
/// Key type
typedef _K = String;

/// Value type
typedef _V = Object?;

/// Model type
typedef Model = Map<_K, _V>;

/// Model list type
typedef ModelList = List<Model>;

/// Model entry
typedef ModelEntry = MapEntry<_K, _V>;

/// Create a new model
Model newModel() => <_K, _V>{};
