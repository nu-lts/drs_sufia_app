class Collection < ActiveFedora::Base
  include ActiveModel::MassAssignmentSecurity
  include Hydra::ModelMixins::RightsMetadata
  include Hydra::ModelMethods
  include Cerberus::Rights::MassPermissions
  include Cerberus::Rights::Embargoable
  include Cerberus::Rights::InheritedRestrictions
  include Cerberus::Rights::PermissionsAssignmentHelper
  include Cerberus::MetadataAssignment
  include Cerberus::Relationships
  include Cerberus::Find

  validate :belong_check, on: :update

  attr_accessible :title, :description, :date, :keywords, :parent
  attr_accessible :creators, :smart_collection_type

  attr_protected :identifier

  has_metadata name: 'DC', type: DublinCoreDatastream
  has_metadata name: 'rightsMetadata', type: ParanoidRightsDatastream
  has_metadata name: 'properties', type: PropertiesDatastream
  has_metadata name: 'mods', type: ModsDatastream

  has_file_datastream "thumbnail_1", type: FileContentDatastream
  has_file_datastream "thumbnail_2", type: FileContentDatastream
  has_file_datastream "thumbnail_3", type: FileContentDatastream

  has_many :child_files, property: :is_member_of, :class_name => "CoreFile"
  has_many :stepchild_files, property: :is_also_member_of, :class_name => "CoreFile"
  has_many :child_collections, property: :is_member_of, :class_name => "Collection"

  belongs_to :parent, property: :is_member_of, :class_name => "Collection"
  belongs_to :user_parent, property: :is_member_of, :class_name => "Employee"
  belongs_to :community_parent, property: :is_member_of, :class_name => "Community"

  def to_solr(solr_doc = Hash.new())
    if self.tombstoned?
      solr_doc["id"] = self.pid
      solr_doc["tombstoned_ssi"] = 'true'
      solr_doc["title_info_title_ssi"] = self.title
      solr_doc["parent_id_tesim"] = self.properties.parent_id
      solr_doc["active_fedora_model_ssi"] = self.class
      solr_doc["tombstone_reason_tesim"] = self.tombstone_reason if self.tombstone_reason
      solr_doc["identifier_tesim"] = self.identifier if self.identifier
      solr_doc["tombstone_date_ssi"] = DateTime.now.strftime("%Y-%m-%dT%H:%M:%SZ")
      return solr_doc
    end

    super(solr_doc)
    solr_doc["type_sim"] = I18n.t("drs.display_labels.#{self.class}.name")
    return solr_doc
  end

  def parent
    single_lookup(:is_member_of, [Collection, Community])
  end

  def sentinel
    Sentinel.where(:set_pid => self.pid).last
  end

  # Override parent= so that the string passed by the creation form can be used.
  def parent=(val)
    unique_assign_by_string(val, :is_member_of, [Collection, Community], allow_nil: true)

    if !val.nil?
      if val.instance_of? String
        self.properties.parent_id = val
      else
        self.properties.parent_id = val.pid
      end
    end
  end

  # Override user_parent= so that the string passed by the creation form can be used.
  def user_parent=(employee)
    if employee.instance_of?(String)
      self.add_relationship(:is_member_of, Employee.find_by_nuid(employee))
    elsif employee.instance_of? Employee
      self.add_relationship(:is_member_of, employee)
    else
      raise "user_parent= got passed a #{employee.class}, which doesn't work."
    end
  end

  # Depth first(ish) traversal of a graph.
  def each_depth_first
    self.child_collections.each do |child|
      child.each_depth_first do |c|
        yield c
      end
    end

    yield self
  end

  def tombstone(reason = "")
    self.properties.tombstoned = 'true'
    doc = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{self.pid}\"").first)
    if doc.child_files
      doc.child_files.each do |child|
        cf = CoreFile.find(child.pid)
        if reason != ""
          cf.tombstone(reason)
        else
          cf.tombstone
        end
      end
    end
    if self.child_collections
      self.child_collections.each do |col_child|
        if reason != ""
          col_child.tombstone(reason)
        else
          col_child.tombstone
        end
      end
    end
    if reason != ""
      array = []
      self.mods.access_condition.each_with_index do |ac, i|
        hash = {}
        hash[:type] = self.mods.access_condition(i).type[0]
        hash[:value] = self.mods.access_condition[i]
        array << hash if !hash.blank?
      end
      array << {:type=>"suppressed",:value=>reason}
      self.mods.access_conditions = array
    end
    self.save!
  end

  def revive
    if self.properties.parent_id[0]
      parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{self.properties.parent_id[0]}\"").first)
    elsif self.parent
      parent = parent
    else
      parent = nil
    end
    if parent && parent.tombstoned?
      return false
    else
      self.properties.tombstoned = ''
      self.mods.remove_suppressed_access
      self.save!
      cfs = ActiveFedora::SolrService.query("parent_id_tesim:\"#{self.pid}\"")
      cfs.each do |cf|
        if cf['active_fedora_model_ssi'] == 'CoreFile'
          child = CoreFile.find(cf['id'])
          child.revive
        elsif cf['active_fedora_model_ssi'] == 'Collection'
          col_child = Collection.find(cf['id'])
          col_child.revive
        end
      end
    end
  end

  def tombstoned?
    if self.properties.tombstoned.first.nil? || self.properties.tombstoned.first.empty?
      return false
    else
      return true
    end
  end

  def tombstone_reason
    if self.mods.access_condition
      self.mods.access_condition.each_with_index do |ac, i|
        if self.mods.access_condition(i).type[0] == "suppressed"
          return self.mods.access_condition[i]
        end
      end
    else
      return
    end
  end

  protected

    def belong_check
      if single_lookup(:is_member_of, [Community]) && single_lookup(:is_member_of, [Collection])
        errors.add(:identifier, "#{self.pid} already has a parent relationship")
      end
    end
end
