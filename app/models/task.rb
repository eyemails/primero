class Task

  attr_accessor :parent_case, :priority, :case_id

  def self.from_case(records)
    records = [records] unless records.is_a?(Array)
    tasks = []
    records.each do |record|
      tasks += [Tasks::AssessmentTask, Tasks::CasePlanTask, Tasks::FollowUpTask, Tasks::ServiceTask].map do |task_clazz|
        task_clazz.from_case(record)
      end.flatten
    end
    tasks.sort_by!(&:due_date)
  end

  def initialize(record)
    self.parent_case = record
    self.priority = record.try(:risk_level)
    self.case_id = record.case_id_display
  end

  def type
    self.class.name[0..-5].underscore
  end

  def type_display(lookups=nil)
    I18n.t("task.types.#{self.type}")
  end

  def overdue?
    self.due_date < Date.today
  end

  def upcoming_soon?
    !self.overdue? && self.due_date <= 7.days.from_now
  end

end
