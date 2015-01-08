module ReferActions
  extend ActiveSupport::Concern

  include SelectActions

  def referral
    authorize! :referral, model_class

    get_selected_ids

    @referral_records = []
    if @selected_ids.present?
      @referral_records = model_class.all(keys: @selected_ids).all
    else
      #Refer all records
      @filters = record_filter(filter)
      @referral_records, @total_records = retrieve_records_and_total(@filters)
    end

    if params[:is_remote].present? && params[:is_remote] == 'true'
      remote_referral(@referral_records)
    else
      #local instance referral
      redirect_to :back
    end
  end

  def remote_referral(referral_records)
    if params[:remote_primero].present? && params[:remote_primero] == 'true'
      #remote Primero instance referral
      exporter = Exporters::JSONExporter
    else
      #remote non-Primero instance referral
      exporter = Exporters::CSVExporter
    end
    props = filter_permitted_export_properties(referral_records, exported_properties)
    export_data = exporter.export(referral_records, props, current_user)
    encrypt_data_to_zip export_data, referral_filename(referral_records, exporter), params[:referral_password]
  end

  def referral_filename(models, exporter)
    if params[:referral_file_name].present?
      "#{params[:referral_file_name]}.#{exporter.mime_type}"
    elsif models.length == 1
      "#{models[0].unique_identifier}.#{exporter.mime_type}"
    else
      "#{current_user.user_name}-#{model_class.name.underscore}.#{exporter.mime_type}"
    end
  end

end