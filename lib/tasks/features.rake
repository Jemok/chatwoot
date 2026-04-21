namespace :features do
  desc 'Enable every feature listed in config/features.yml for every account'
  task enable_all: :environment do
    feature_names = YAML.load_file(Rails.root.join('config/features.yml')).map { |f| f['name'] }
    Account.find_each do |account|
      enabled = []
      feature_names.each do |name|
        account.enable_features(name)
        if account.save
          enabled << name
        else
          account.reload
        end
      rescue ActiveModel::RangeError
        account.reload
      end
      puts "Enabled #{enabled.size}/#{feature_names.size} features for account ##{account.id} (#{account.name})"
    end
  end
end

