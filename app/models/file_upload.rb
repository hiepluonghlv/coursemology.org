class FileUpload < ActiveRecord::Base
  attr_accessible :owner_id, :owner_type, :creator_id, :owner, :file, :creator, :original_name

  belongs_to :owner, :polymorphic => true
  belongs_to :creator, class_name: "User"

  has_attached_file :file

  before_post_process :hash_filename
  after_save :save_s3_filename

  include Rails.application.routes.url_helpers
  require 'digest/md5'

  def to_jq_upload
    {
        "id"    =>  read_attribute(:id),
        "name"  => read_attribute(:file_file_name),
        "size"  => read_attribute(:file_file_size),
        "url"   => file.url(:original),
        "original" => read_attribute(:original_name),
        "timestamp" => created_at.strftime("%d-%m-%Y %H:%M:%S"),
        "delete_url"  => file_upload_path(self),
        "delete_type" => "DELETE"
    }
  end

  # Gets the display filename for the upload: It will give the original name if present, otherwise
  # it will be the (obfuscated) storage filename
  def display_filename
    original_name || file_file_name
  end

  def hash_filename
    self.original_name = self.file_file_name.to_s
    self.file.instance_write(:file_name, "#{Digest::MD5.hexdigest(self.file_file_name)}#{File.extname(self.file_file_name)}")
  end

private
  def save_s3_filename
    if not self.file then
      return
    end

    obj = file.s3_object
    if not obj then
      return
    end

    # Preserve the ACL of the file we are replacing
    acl = obj.acl

    # Copy the file in place -- this replaces the headers but retains content
    new_obj = obj.copy_to(obj.key, :content_disposition => 'attachment; filename=' + original_name)

    # Restore ACL since copy_to does not preserve it
    new_obj.acl = acl
  end
end
