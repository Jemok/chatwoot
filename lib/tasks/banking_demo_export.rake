# Banking demo: export/import inbox skeletons across environments (e.g. laptop
# → Contabo VPS) without moving session-bound tokens. See docs/ for usage.
#
#   # on source (localhost)
#   bundle exec rake "banking_demo:export_inboxes[1,tmp/inboxes.yml]"
#
#   # copy tmp/inboxes.yml to the VPS, then:
#   RAILS_ENV=production bundle exec rake "banking_demo:import_inboxes[1,tmp/inboxes.yml]"
#
# The importer creates skeleton Channel::Api inboxes with identical names and
# queue_kind so the Moderation Center / simulators behave identically. Real
# FB/IG/Threads/X channels must be re-authorized on the target via the
# Chatwoot UI; the callbacks controller will then auto-create the four-inbox
# layout (DM, Mentions, Visitor Posts, Comments) per page.

namespace :banking_demo do
  desc 'Export inbox skeletons for an account to a YAML file'
  task :export_inboxes, %i[account_id path] => :environment do |_, args|
    account = Account.find(args[:account_id])
    path = args[:path].presence || "tmp/inboxes_account_#{account.id}.yml"

    data = {
      'account_id' => account.id,
      'exported_at' => Time.current.iso8601,
      'inboxes' => account.inboxes.order(:id).map do |inbox|
        {
          'name' => inbox.name,
          'channel_type' => inbox.channel_type,
          'queue_kind' => inbox.queue_kind,
          'greeting_enabled' => inbox.greeting_enabled,
          'greeting_message' => inbox.greeting_message,
          'enable_auto_assignment' => inbox.enable_auto_assignment,
          'working_hours_enabled' => inbox.working_hours_enabled,
          'agent_emails' => inbox.inbox_members.includes(:user).map { |m| m.user.email }.sort
        }
      end,
      'labels' => account.labels.order(:id).pluck(:title, :description, :color).map { |t, d, c| { 'title' => t, 'description' => d, 'color' => c } },
      'teams' => account.teams.order(:id).pluck(:name, :description).map { |n, d| { 'name' => n, 'description' => d } },
      'canned_responses' => account.canned_responses.order(:id).pluck(:short_code, :content).map { |s, c| { 'short_code' => s, 'content' => c } }
    }

    File.write(path, data.to_yaml)
    puts "Exported #{data['inboxes'].size} inboxes, #{data['labels'].size} labels, #{data['teams'].size} teams, #{data['canned_responses'].size} canned responses to #{path}"
  end

  desc 'Import inbox skeletons from a YAML file into the target account'
  task :import_inboxes, %i[account_id path] => :environment do |_, args|
    account = Account.find(args[:account_id])
    path = args[:path]
    raise "File not found: #{path}" unless File.exist?(path)

    data = YAML.safe_load_file(path, permitted_classes: [Time, Date])

    ActiveRecord::Base.transaction do
      (data['labels'] || []).each do |row|
        account.labels.find_or_create_by!(title: row['title']) do |l|
          l.description = row['description']
          l.color = row['color']
        end
      end

      (data['teams'] || []).each do |row|
        account.teams.find_or_create_by!(name: row['name']) { |t| t.description = row['description'] }
      end

      (data['canned_responses'] || []).each do |row|
        account.canned_responses.find_or_create_by!(short_code: row['short_code']) { |c| c.content = row['content'] }
      end

      (data['inboxes'] || []).each do |row|
        next if account.inboxes.exists?(name: row['name']) # idempotent

        channel = Channel::Api.create!(account: account)
        inbox = account.inboxes.create!(
          name: row['name'],
          channel: channel,
          queue_kind: row['queue_kind'],
          greeting_enabled: row['greeting_enabled'] || false,
          greeting_message: row['greeting_message'],
          enable_auto_assignment: row['enable_auto_assignment'].nil? ? true : row['enable_auto_assignment'],
          working_hours_enabled: row['working_hours_enabled'] || false
        )

        (row['agent_emails'] || []).each do |email|
          user = User.find_by(email: email)
          next unless user

          account_user = AccountUser.find_by(account: account, user: user)
          next unless account_user

          InboxMember.find_or_create_by!(inbox: inbox, user: user)
        end
      end
    end

    puts "Imported skeletons into account ##{account.id}. Re-authorize FB/IG/Threads/X channels via Settings → Inboxes to wire real webhooks."
  end
end

