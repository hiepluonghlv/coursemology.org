class LessonPlanEntry < ActiveRecord::Base
  attr_accessible :title, :entry_type, :description, :start_at, :end_at, :location, :resources

  validates_with DateValidator, fields: [:start_at, :end_at]

  belongs_to :course
  belongs_to :creator, class_name: "User"
  has_many :resources, class_name: "LessonPlanResource"

  has_many :taggable_tags, as: :taggable, dependent: :destroy
  has_many :topicconcepts, through: :taggable_tags, source: :tag, source_type: "Topicconcept"

  after_save :save_resources
  
  def save_resources
    if self.resources then
      self.resources.each { |r|
        r.save
      }
    end
  end

  # Creates a virtual item of this class that is backed by some other data store.
  def self.create_virtual
    (Class.new do
      def initialize
        @title = @description = @real_type = @start_at = @end_at = nil
        @resources = []
      end

      def title
        @title
      end
      def title=(title)
        @title = title
      end
      def entry_type
        3
      end
      def entry_real_type
        @real_type
      end
      def entry_real_type=(type)
        @real_type = type
      end
      def description
        @description
      end
      def description=(description)
        @description = description
      end
      def start_at
        @start_at
      end
      def start_at=(start_at)
        @start_at = start_at
      end
      def end_at
        @end_at
      end
      def end_at=(end_at)
        @end_at = end_at
      end
      def resources
        @resources
      end
      def resources=(resources)
        @resources = resources
      end
      def location
        nil
      end

      # Extra property that real entries do not have, so we can jump to them.
      def url
        @url
      end
      def url=(url)
        @url = url
      end
      
      def is_virtual?
        true
      end
      
      def is_published
        @is_published
      end
      
      def is_published=(is_published)
        @is_published = is_published
      end
    end).new
  end

  # Defines all the types
  ENTRY_TYPES = [
    ['Lecture', 0],
    ['Recitation', 1],
    ['Tutorial', 2],
    ['Video', 3],
    ['Other', 4]
  ]

  def entry_real_type
    LessonPlanEntry::ENTRY_TYPES[self.entry_type][0]
  end
  
  def is_virtual?
    false
  end
  def is_published
    true
  end
end
