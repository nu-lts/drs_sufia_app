class WorkIndexer < ActiveFedora::IndexingService
  include IndexesThumbnails

  self.thumbnail_path_service = ThumbnailPathService
  def generate_solr_document
    super.tap do |solr_doc|
      Solrizer.set_field(solr_doc, 'generic_type', 'Work', :stored_searchable)

      if !object.parent.blank?
        solr_doc[Solrizer.solr_name('member_of_collection_ids', :symbol)] = object.parent.id
      end
    end
  end
end
