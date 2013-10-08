module Drs
  module NuFile
    extend ActiveSupport::Concern
    include ActiveModel::MassAssignmentSecurity
    include Hydra::ModelMethods
    include Hydra::ModelMixins::RightsMetadata
    include Drs::MetadataAssignment
    include Drs::Rights::MassPermissions
    include Drs::NuFile::Characterizable
    include Hydra::Derivatives 

    included do
      attr_accessible :title, :description, :keywords, :identifier
      attr_accessible :depositor, :date_of_issue, :core_record 
      attr_accessible :creators

      has_metadata name: 'DC', type: NortheasternDublinCoreDatastream 
      has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
      has_metadata name: 'properties', type: DrsPropertiesDatastream
      has_file_datastream name: "content", type: FileContentDatastream
      
      belongs_to :core_record, property: :is_part_of, class_name: 'NuCoreFile'
    end

    def self.create_master_content_object(core_file, file, datastream_id, user)
      Drs::NuFile::MasterCreator.create(core_file, file, datastream_id, user)
    end

    def self.virus_check(file)
      if defined? ClamAV
        stat = ClamAV.instance.scanfile(file.path)
        logger.warn "Virus checking did not pass for #{file.inspect} status = #{stat}" unless stat == 0
        stat
      else
        logger.warn "Virus checking disabled for #{file.inspect}"
        0
      end
    end
  end
end