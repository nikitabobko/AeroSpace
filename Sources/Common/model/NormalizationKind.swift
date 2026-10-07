/// Identifies a refresh-time normalization that may be enabled or disabled
/// independently of the others. Raw value matches the corresponding
/// `enable-normalization-<kebab-name>` config key.
public enum NormalizationKind: String, CaseIterable, Sendable, Equatable {
    case flattenContainers = "flatten-containers"
    case oppositeOrientationForNestedContainers = "opposite-orientation-for-nested-containers"
}
