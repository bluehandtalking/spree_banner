module Spree
  class Banner < ActiveRecord::Base
  
    has_attached_file :attachment,
                :url  => "/spree/banner/:id/:style_:basename.:extension",
                :path => ":rails_root/public/spree/banner/:id/:style_:basename.:extension",
                #:default_url => "/missing/:style.jpg",
                :styles => {
                      :thumbnail => "80x80#",
                      :custom => Proc.new { |instance| "#{instance.attachment_width}x#{instance.attachment_height}#" }
                },
                :convert_options => {
                      :thumbnail => "-gravity center"
                }
    after_post_process :find_dimensions
    
    validates_presence_of :category, :attachment_width, :attachment_height
    validates_attachment_presence :attachment
    validates_attachment_content_type :attachment, :content_type => ['image/jpeg', 'image/png', 'image/gif'], :message => "deve essere JPG, JPEG o PNG"
    #process_in_background :image UTILE MA OCCORRE ATTIVARE ANCHE LA GEMMA DELAYED-PAPERCLIP
    scope :enable, lambda { |category| {:conditions => {:enabled => true, :category => category}} }
    
    # Load S3 settings
    if (!YAML.load_file(Rails.root.join('config', 's3.yml'))[Rails.env].blank?)
      S3_OPTIONS = {
              :storage => 's3',
              :s3_credentials => Rails.root.join('config', 's3.yml')
            }
    elsif (ENV['S3_KEY'] && ENV['S3_SECRET'] && ENV['S3_BUCKET'])
      S3_OPTIONS = {
              :storage => 's3',
              :s3_credentials => {
                :access_key_id     => ENV['S3_KEY'],
                :secret_access_key => ENV['S3_SECRET']
              },
              :bucket => ENV['S3_BUCKET']
            }
    else
      S3_OPTIONS = { :storage => 'filesystem' }
    end
    
    attachment_definitions[:attachment] = (attachment_definitions[:attachment] || {}).merge(S3_OPTIONS)
    
    def initialize(*args)
      super(*args)
      last_banner = Banner.last
      self.position = last_banner ? last_banner.position + 1 : 0
    end
    
    def find_dimensions
      temporary = attachment.queued_for_write[:original]
      filename = temporary.path unless temporary.nil?
      filename = attachment.path if filename.blank?
      geometry = Paperclip::Geometry.from_file(filename)
      self.attachment_width  = geometry.width
      self.attachment_height = geometry.height
    end
    
  end
end
