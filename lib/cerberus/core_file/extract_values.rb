module Cerberus
  module CoreFile
    module ExtractValues

      include ApplicationHelper

      def to_hash
        @core_doc = SolrDocument.new(self.to_solr)
        mods_json = fetch_mods_json
        result_hsh = Hash.new
        result_hsh["pid"] = self.pid
        result_hsh["breadcrumbs"] = breadcrumb_to_root(SolrDocument.new(self.to_solr))
        result_hsh["parent"] = @core_doc.parent
        if !@core_doc.ordinal_value.blank?
          result_hsh["ordinal_value"] = @core_doc.ordinal_value
        end
        result_hsh["thumbnails"] = @core_doc.thumbnail_list.map { |url_string| "#{root_path(:only_path => false)}#{url_string.sub!(/^\//, '')}"}
        result_hsh["canonical_object"] = @core_doc.canonical_object.map { |doc| {doc_to_url(doc) => doc.derivative_label} }.reduce(&:merge)
        result_hsh["content_objects"] = @core_doc.content_objects.map { |doc| {doc_to_url(doc) => doc.derivative_label} }.reduce(&:merge)
        result_hsh["mods"] = JSON.parse(mods_json)

        associated_docs = []
        associated_docs.push(*@core_doc.instructional_materials)
        associated_docs.push(*@core_doc.supplemental_materials)

        # Associated Files - key/val - pid/title
        result_hsh["associated"] = associated_docs.map { |doc| { doc.pid => doc.title } }.reduce(&:merge)

        if !@core_doc.niec_values.blank?
          result_hsh["niec"] = @core_doc.niec_values
        end

        return result_hsh
      end

      protected
        def doc_to_url(solr_doc)
          return download_path(solr_doc.pid, :only_path => false)
        end

        def fetch_mods_json
          CoreFilesController.new.render_mods_display(self).to_json
        end

        # Generates a hash of breadcrumbs back to the Root Collection
        def breadcrumb_to_root(item, breadcrumb = Hash.new)
          if breadcrumb.empty?
            title_str = CGI::unescapeHTML "#{item.non_sort} #{kramdown_parse(item.title)}"
            breadcrumb["#{item.pid}"] = title_str.strip.html_safe
          end

          if item.parent.nil? || item.parent == "neu:1"
            return breadcrumb
          else
            parent = SolrDocument.new(ActiveFedora::SolrService.query("id:\"#{item.parent}\"").first)
            breadcrumb["#{parent.pid}"] = kramdown_parse(parent.title.strip)
            breadcrumb_to_root(parent, breadcrumb)
          end
        end
    end
  end
end
