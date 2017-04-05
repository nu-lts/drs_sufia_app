class IiifImageCreateJob
  # this job loops through a collection and converts all 16bit tifs to 8bit tifs and adds the 8bit tif as a ImageLargeFile off the core_file with properties.iiif set to true (8bit tifs are necessary for loris to behave properly)

  include MimeHelper
  include ChecksumHelper
  require 'RMagick'
  include Magick
  include Cerberus::TempFileStorage
  include SentinelHelper

  attr_accessor :collection_pid

  def initialize(collection_pid)
    self.collection_pid = collection_pid
  end

  def run
    if Collection.exists?(collection_pid)
      col = Collection.find(collection_pid)
      start_time = "#{Time.now.to_i}"
      progress_logger = Logger.new("#{Rails.root}/log/iiif-image-create-job_#{start_time}.log")
      progress_logger.info "#{Time.now} - Processing #{col.pid} files."
      begin
        children = col.all_descendent_files
        children.each do |child|
          if !child.iiif_object
            if child.mime_type == "image/tiff" || child.mime_type == "image/tif"
              img = Magick::Image::read(child.canonical_object.fedora_file_path).first
              if img.channel_depth > 8 # check if it has a bit depth greater than 8
                tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
                uniq_hsh = Digest::MD5.hexdigest("#{File.basename(child.canonical_object.fedora_file_path)}")[0,2]
                new_path = tempdir.join("#{Time.now.to_f.to_s.gsub!('.','-')}-#{uniq_hsh}")
                FileUtils.cp(child.canonical_object.fedora_file_path, new_path.to_s)
                new_path = new_path.to_s
                new_img_path = new_path+"_8bit"
                new_img = Magick::Image::read(new_path).first
                new_img.write(new_img_path) do
                  self.depth = 8
                end
                progress_logger.info Magick::Image::read(new_img_path).first.channel_depth
                content_object = ImageLargeFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
                content_object.tmp_path = new_img_path
                checksum = new_checksum(new_img_path)
                content_object.properties.md5_checksum = checksum
                content_object.original_filename = child.canonical_object.original_filename
                content_object.depositor = child.depositor
                content_object.save!
                # note that this loads the file into memory - if we start running this on large files, it's likely to need to the large_upload functionality from the content_creation_job
                File.open(new_img_path) do |file_contents|
                  content_object.add_file(file_contents, 'content', content_object.original_filename)
                  content_object.save!
                end
                content_object.reload
                content_object.proxy_uploader = child.proxy_uploader
                sentinel = child.parent.sentinel
                if sentinel && !sentinel.send(sentinel_class_to_symbol("ImageLargeFile")).blank?
                  # set content object to sentinel value
                  content_object.permissions = sentinel.send(sentinel_class_to_symbol("ImageLargeFile"))["permissions"]
                  content_object.mass_permissions = sentinel.send(sentinel_class_to_symbol("ImageLargeFile"))["mass_permissions"]
                  content_object.save!
                else
                  content_object.rightsMetadata.content = child.canonical_object.rightsMetadata.content
                end
                content_object.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit") #verify repo staff rights
                content_object.core_record = child
                content_object.title = content_object.original_filename
                content_object.identifier = content_object.pid
                content_object.properties.mime_type = extract_mime_type(new_img_path)
                content_object.properties.iiif = "true"
                content_object.save!
                Rails.cache.delete_matched("/content_objects/#{child.pid}*") #clear content_object cache
                FileUtils.rm(new_path) # clean up tmp
                FileUtils.rm(new_img_path)
                progress_logger.info "#{content_object.pid} created for #{child.pid}"
              else
                progress_logger.info "#{child.pid} does not have bit depth greater than 8"
              end
            else
              progress_logger.info "#{child.pid} is not a tif"
            end
          else
            progress_logger.info "#{child.pid} has a iiif object already"
          end
        end
      rescue Exception => error
        progress_logger.warn "Exception caught - #{error.to_s}"
      end
      progress_logger.close()
      return "IIIF Image Creation Job Completed - log is located at #{Rails.root}/log/iiif-image-create-job_#{start_time}.log"
    else
      raise ActiveFedora::ObjectNotFoundError
    end
  end
end