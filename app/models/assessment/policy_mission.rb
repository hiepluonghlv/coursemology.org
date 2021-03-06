class Assessment::PolicyMission < ActiveRecord::Base
  acts_as_paranoid
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

	attr_accessible  :title, :description, :exp, :open_at, :close_at, :published, :comment_per_qn,
                   :dependent_id, :display_mode_id

  validates_presence_of :title, :exp, :open_at, :close_at
	
	has_one :progression_policy, class_name: "Assessment::ProgressionPolicy",  dependent: :destroy

	
	def full_title
    "#{I18n.t('Assessment.Policy_Mission')} : #{self.title}"
  end

  def self.reflect_on_association(association)
    super || self.parent.reflect_on_association(association)
  end

end
