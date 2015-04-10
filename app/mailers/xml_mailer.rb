class XmlMailer < ActionMailer::Base
  default from: "notifier@repository.library.northeastern.edu"
  after_filter :tag_as_notified

  def daily_xml_email

    @diff_css = Diffy::CSS
    @xml_edits = XmlAlert.where('notified = ?', false).find_all

    mail(to: pick_receiver,
         subject: "Daily digest of XML edits - #{@xml_edits.count} items",
         content_type: "text/html")
  end

  private
    def tag_as_notified
      @xml_edits.each do |alert|
        alert.notified = true
        alert.save
      end
    end

    def pick_receiver
      if ["production"].include? Rails.env
        "Library-DRS-Metadata@neu.edu"
      elsif "test" == Rails.env
        "test@test.com"
      else
        if File.exist?('/home/vagrant/.gitconfig')
          git_config = ParseConfig.new('/home/vagrant/.gitconfig')
          git_config['user']['email']
        end
      end
    end
end
