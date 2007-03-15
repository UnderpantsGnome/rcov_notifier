class RcovNotifier
  attr_accessor :min_threshold, :max_threshold, :rcov_index, :recipients, 
    :send_status_every_n_builds

  def initialize(project); end

  def build_finished(build)
    return if build.failed? || ! rcov_index || ! min_threshold || ! recipients
    total_coverage = 0

    file_name = File.expand_path(
      File.join(build.artifacts_directory, rcov_index))

    if File.exists?(file_name)
      subject = message = nil
      File.open(file_name).each_line do |line|
        if line =~ /<tt.*?>(\d+\.\d+)%<\/tt>&nbsp;<\/td>/
          total_coverage = eval($1)
          if total_coverage < min_threshold.to_f
            message = subject = "#{build.project.name}:#{build.label} Coverage below threshold, #{total_coverage} < #{min_threshold}"
          elsif total_coverage > max_threshold.to_f
            subject = "#{build.project.name}:#{build.label} Coverage above threshold, #{total_coverage} > #{max_threshold}"
            message = "#{subject} \n\nYou should adjust your min_threshold."
          elsif send_status_every_n_builds && build.label.to_i % send_status_every_n_builds == 0
            message = subject = "#{build.project.name}:#{build.label} Coverage is (#{total_coverage})"
          end
          break
        end
      end

      if subject
        CruiseControl::Log.event(subject, :debug)
        message << "\n"
        notify(build, subject, message)
      end
    else
      CruiseControl::Log.event("RcovNotifier: Unable to find rcov_index: #{file_name}", :error)
    end
  end

private

  def notify(build, subject, message)
    CruiseControl::Log.event("sending: #{subject}, to:#{recipients.join(' ')}", :debug)
    BuildMailer.send(:deliver_build_report, build, recipients, subject, message)
    CruiseControl::Log.event("Sent e-mail to #{recipients.size == 1 ? "1 person" : "#{recipients.size} people"}", :debug)
  rescue => e
    settings = ActionMailer::Base.smtp_settings.map { |k,v| "  #{k.inspect} = #{v.inspect}" }.join("\n")
    CruiseControl::Log.event("Error sending e-mail - current server settings are :\n#{settings}", :error)
    raise
  end
end

Project.plugin :rcov_notifier