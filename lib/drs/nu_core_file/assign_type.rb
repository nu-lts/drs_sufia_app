require 'filemagic'

module Drs
  module NuCoreFile
    module AssignType

      def instantiate_appropriate_content_object(file_path, file_name)
        fmagic = FileMagic.new(FileMagic::MAGIC_MIME).file(file_path)
        fmagic_result = hash_fmagic(fmagic)

        if is_image?(fmagic_result)
          self.canonical_class = "ImageMasterFile"
        elsif is_pdf?(fmagic_result)
          self.canonical_class = "PdfFile"
        elsif is_audio?(fmagic_result)
          self.canonical_class = "AudioFile"
        elsif is_video?(fmagic_result)
          self.canonical_class = "VideoFile"
        elsif is_msword?(fmagic_result, file_name)
          self.canonical_class = "MswordFile"
        elsif is_msexcel?(fmagic_result, file_name)
          self.canonical_class = "MsexcelFile"
        elsif is_msppt?(fmagic_result, file_name)
          self.canonical_class = "MspowerpointFile"
        elsif is_texty?(fmagic_result)
          self.canonical_class = "TextFile"
        else
          self.canonical_class = "ZipFile"
        end

        assign_dcmi_type
      end

      private

        # Tag core with a DCMI noun based on the sort of content object created.
        def assign_dcmi_type
          if [ImageMasterFile, VideoFile].include? self.canonical_class.constantize
            self.dcmi_type = "image"
          elsif [TextFile, PdfFile, MswordFile].include? self.canonical_class.constantize
            self.dcmi_type = "text"
          elsif self.canonical_class.constantize.is_a? AudioFile
            self.dcmi_type = "audio"
          elsif self.canonical_class.constantize.is_a? MsexcelFile
            self.dcmi_type = "dataset"
          elsif self.canonical_class.constantize.is_a? MspowerpointFile
            self.dcmi_type = "interactive resource"
          elsif self.canonical_class.constantize.is_a? ZipFile
            self.dcmi_type = "unknown"
          end

          self.save! ? core_record : Rails.logger.warn("Failed to update #{core_record.pid}'s dcmi type")
        end

        # Takes a string like "image/jpeg ; encoding=binary", generated by FileMagic.
        # And turns it into the hash {raw_type: 'image', sub_type: 'jpeg', encoding: 'binary'}
        def hash_fmagic(fmagic_string)
          ary = fmagic_string.split(";")

          result = {}
          result[:raw_type] = ary.first.split("/").first.strip
          result[:sub_type] = ary.first.split("/").last.strip
          result[:encoding] = ary.last.split("=").last.strip
          return result
        end

        def is_image?(fm_hash)
          return fm_hash[:raw_type] == 'image'
        end

        def is_pdf?(fm_hash)
          return fm_hash[:sub_type] == 'pdf'
        end

        def is_video?(fm_hash)
          return fm_hash[:raw_type] == 'video'
        end

        def is_audio?(fm_hash)
          return fm_hash[:raw_type] == 'audio'
        end

        def is_msword?(fm_hash, fname)
          signature = ['zip', 'msword', 'octet-stream', 'vnd.openxmlformats-officedocument.wordprocessingml.document'].include? fm_hash[:sub_type]
          file_extension = ['docx', 'doc'].include? fname.split(".").last
          return signature && file_extension
        end

        def is_msexcel?(fm_hash, fname)
          signature = ['zip', 'vnd.ms-office'].include? fm_hash[:sub_type]
          file_extension = ['xls', 'xlsx', 'xlw'].include? fname.split(".").last
          return signature && file_extension
        end

        def is_msppt?(fm_hash, fname)
          signature = ['zip', 'vnd.ms-powerpoint'].include? fm_hash[:sub_type]
          file_extension = ['ppt', 'pptx', 'pps', 'ppsx'].include? fname.split(".").last
          return signature && file_extension
        end

        def is_texty?(fm_hash)
          return fm_hash[:raw_type] == 'text'
        end

    end
  end
end
