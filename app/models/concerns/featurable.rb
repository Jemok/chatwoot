module Featurable
  extend ActiveSupport::Concern

  QUERY_MODE = {
    flag_query_mode: :bit_operator,
    check_for_column: false
  }.freeze

  FEATURE_LIST = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze

  # bigint (signed 8 bytes) can safely hold up to 63 flags per column.
  # Additional features overflow into successive columns: feature_flags, feature_flags_2, ...
  FEATURE_FLAGS_PER_COLUMN = 63

  FEATURE_COLUMNS = FEATURE_LIST.each_with_index.each_with_object({}) do |(feature, index), result|
    column_index = index / FEATURE_FLAGS_PER_COLUMN
    column_name = column_index.zero? ? 'feature_flags' : "feature_flags_#{column_index + 1}"
    result[column_name] ||= {}
    result[column_name][(index % FEATURE_FLAGS_PER_COLUMN) + 1] = "feature_#{feature['name']}".to_sym
  end.freeze

  FEATURES = FEATURE_LIST.each_with_object({}) do |feature, result|
    result[result.keys.size + 1] = "feature_#{feature['name']}".to_sym
  end

  included do
    include FlagShihTzu
    FEATURE_COLUMNS.each do |column_name, flags|
      has_flags flags.merge(column: column_name).merge(QUERY_MODE)
    end

    before_create :enable_default_features
  end

  def enable_features(*names)
    names.each do |name|
      send("feature_#{name}=", true)
    end
  end

  def enable_features!(*names)
    enable_features(*names)
    save
  end

  def disable_features(*names)
    names.each do |name|
      send("feature_#{name}=", false)
    end
  end

  def disable_features!(*names)
    disable_features(*names)
    save
  end

  def feature_enabled?(name)
    send("feature_#{name}?")
  end

  def all_features
    FEATURE_LIST.pluck('name').index_with do |feature_name|
      feature_enabled?(feature_name)
    end
  end

  def enabled_features
    all_features.select { |_feature, enabled| enabled == true }
  end

  def disabled_features
    all_features.select { |_feature, enabled| enabled == false }
  end

  private

  def enable_default_features
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return true if config.blank?

    features_to_enabled = config.value.select { |f| f[:enabled] }.pluck(:name)
    enable_features(*features_to_enabled)
  end
end
