module Api
  module V1
    class IngestController < ApplicationController

      include Cerberus::TempFileStorage
      include Cerberus::ThumbnailCreation
      include HandleHelper
      include MimeHelper

      def ingest
        # Take an external form, and based on whitelisted IP deposit submission
        ip = request.remote_ip

        begin
          I18n.t "ingest.#{ip.gsub(".", "-")}", raise: true # We replace periods for YML, and raise error if IP not on whitelist
        rescue I18n::MissingTranslationData
          format.json { render :json => { :error => "IP address not on whitelist. DRS administrators have been notified of this attempt.", status: :forbidden}
        end

        if params.blank? || params[:core_file].blank? || params[:file].blank?
          # raise submission empty error
          format.json { render :json => { :error => "Incomplete form submission. File and/or metadata are not available.", status: :bad_request}
        elsif params[:core_file][:title].blank?
          # raise title required error
          format.json { render :json => { :error => "Incomplete form submission. Title missing.", status: :bad_request}
        elsif params[:core_file][:keywords].blank?
          # raises keywords required error
          format.json { render :json => { :error => "Incomplete form submission. Keyword(s) missing.", status: :bad_request}
        end

        core_file = CoreFile.new
        core_file.depositor = "000000000"
        core_file.properties.api_ingested = 'true'

        # Required items;
        # Binary file
        file = params[:file]
        # Title
        core_file.title = params[:core_file][:title]
        # Keyword(s)
        core_file.keywords = params[:core_file][:keywords]

        # Optional items;
        # Subtitle
        core_file.mods.title_info.sub_title = params[:core_file][:subtitle]
        # Date created
        core_file.date_created = params[:core_file][:date_created]
        # Copyright date
        core_file.mods.origin_info.copyright = params[:core_file][:copyright_date]
        # Date published - dateIssued
        core_file.mods.origin_info.date_issued = params[:core_file][:date_published]
        # Publisher name
        core_file.mods.origin_info.publisher = params[:core_file][:publisher]
        # Place of publication
        core_file.mods.origin_info.place = params[:core_file][:place_of_publication]
        # Creator name(s) - first, middle, last
        first_names = params[:core_file][:creators][:first_names]
        last_names = params[:core_file][:creators][:first_names]
        core_file.creators = {'first_names' => first_names, 'last_names'  => last_names}
        # Language(s)
        core_file.languages = params[:core_file][:languages]
        # Description(s)
        core_file.mods.abstracts = params[:core_file][:descriptions]
        # Note(s)
        core_file.mods.notes = params[:core_file][:notes]
        # Use and reproduction - dropdown
        core_file.mods.access_condition = params[:core_file][:use_and_reproduction]
        core_file.mods.access_condition.type = "use and reproduction"

        core_file.save!

        new_path = move_file_to_tmp(file)
        core_file.original_filename = file.original_filename
        core_file.instantiate_appropriate_content_object(new_path, core_file.original_filename)

        core_file.identifier = make_handle(core_file.persistent_url)

        core_file.save!

        Cerberus::Application::Queue.push(ContentCreationJob.new(core_file.pid, core_file.tmp_path, core_file.original_filename))
      end

    end
  end
end
