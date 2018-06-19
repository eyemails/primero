module Exporters
  class IncidentRecorderExporter < BaseExporter
    class << self

      def id
        "incident_recorder_xls"
      end

      def mime_type
        "xls"
      end

      def supported_models
        [Incident]
      end

      def excluded_properties
        ["histories"]
      end

      def authorize_fields_to_user?
        false
      end

    end

    def initialize(output_file_path=nil)
      super(output_file_path)
      @builder = IRBuilder.new(self.buffer)
    end

    def complete
      @builder.close
    end

    # @returns: a String with the Excel file data
    def export(models, _, *args)
       @builder.export(models)
    end

    #private

    #This is a private utility class that encapsulates the business logic of exporting to the GBV IR.
    #The state of the class represents the individual export.
    class IRBuilder
      extend Memoist

      #Spreadsheet is expecting "M" and "F".
      SEX = { "male" => I18n.t("exports.incident_recorder_xls.gender.male"),
              "female" => I18n.t("exports.incident_recorder_xls.gender.female") }

      #TODO: should we change the value in the form section ?.
      #      spreadsheet is expecting the "Age" at the beginning and the dash between blanks.
      AGE_GROUP = { "0-11" => "#{I18n.t("exports.incident_recorder_xls.age_group.age")} 0 - 11",
                    "12-17" => "#{I18n.t("exports.incident_recorder_xls.age_group.age")} 12 - 17",
                    "18-25" => "#{I18n.t("exports.incident_recorder_xls.age_group.age")} 18 - 25",
                    "26-40" => "#{I18n.t("exports.incident_recorder_xls.age_group.age")} 26 - 40",
                    "41-60" => "#{I18n.t("exports.incident_recorder_xls.age_group.age")} 41 - 60",
                    "61+" => I18n.t("exports.incident_recorder_xls.age_group.61_older"),
                    "Unknown" => I18n.t("exports.incident_recorder_xls.age_group.unknown") }

      #TODO - should this come from the lookup translation?
      SERVICE_REFERRED_FROM = {
        "health_medical_services" => "Health / Medical Services",
        "psychosocial_counseling_services" => "Psychosocial / Counseling Services",
        "police_other_security_actor" => "Police / Other Security Actor",
        "legal_assistance_services" => "Legal Assistance Services",
        "livelihoods_program" => "Livelihoods Program",
        "self_referral_first_point_of_contact" => "Self Referral / First Point of Contact",
        "teacher_school_official" => "Teacher / School Official",
        "community_or_camp_leader" => "Community or Camp Leader",
        "safe_house_shelter" => "Safe House / Shelter",
        "other_humanitarian_or_development_actor" => "Other Humanitarian or Development Actor",
        "other_government_service" => "Other Government Service",
        "other" => "Other"
      }

      #TODO ????
      SERVICE_REFERRAL = {
        "Referred" => I18n.t("exports.incident_recorder_xls.service_referral.referred"),
        "No referral, Service provided by your agency" => I18n.t("exports.incident_recorder_xls.service_referral.your_agency"),
        "No referral, Services already received from another agency" => I18n.t("exports.incident_recorder_xls.service_referral.another_agency"),
        "No referral, Service not applicable" => I18n.t("exports.incident_recorder_xls.service_referral.not_applicable"),
        "No, Referral declined by survivor" => I18n.t("exports.incident_recorder_xls.service_referral.declined"),
        "No referral, Service unavailable" => I18n.t("exports.incident_recorder_xls.service_referral.unavailable")
      }

      #TODO ???
      REPORTED_ELSEWHERE = {
        "no" => "No",
        "gbvims-org" => "Yes-GBVIMS Org / Agency",
        "non-gbvims-org" => "Yes-Non GBVIMS Org / Agency"
      }

      def close
        #Print at the end of the processing the data collected
        #because this is batch mode, this is the end of the processing
        #of all records.
        incident_menu
        @workbook.close
      end

      def initialize(buffer)
        #TODO: I am dubious that these values are correctly accumulated.
        #      Shouldn't we be trying to fetch all possible values,
        #      rather than all values for incidents getting exported?
        #TODO - discuss with Pavel to see if this needs to change per SL-542
        @districts = {}
        @counties = {}
        @camps = {}
        @locations = {}
        @caseworker_code = {}
        @age_group_count = -1
        @age_type_count = -1

        @workbook = WriteExcel.new(buffer)
        @data_worksheet = @workbook.add_worksheet('Incident Data')
        @menu_worksheet = @workbook.add_worksheet('Menu Data')

        #Sheet data start at row 1 (based 0 index).
        @row_data = 1
      end

      def incident_data_header
        if @data_headers.blank?
          @data_headers = true
          @data_worksheet.write_row(0, 0, @props.keys)
          #TODO revisit, there is a bug in the gem.
          #set_column_widths(@data_worksheet, props.keys)
        end
      end

      def incident_menu_header
        unless @menu_headers.present?
          @menu_headers = true
          header = [
            I18n.t('exports.incident_recorder_xls.headers.case_worker_code'),
            I18n.t('exports.incident_recorder_xls.headers.ethnicity'),
            I18n.t('exports.incident_recorder_xls.headers.location'),
            I18n.t('exports.incident_recorder_xls.headers.county'),
            I18n.t('exports.incident_recorder_xls.headers.district'),
            I18n.t('exports.incident_recorder_xls.headers.camp')
          ]
          @menu_worksheet.write_row(0, 0, header)
          #TODO revisit, there is a bug in the gem.
          #set_column_widths(@menu_worksheet, header)
        end
      end

      def export(models)
        Exporters::IncidentRecorderExporter.load_fields(models.first) if models.present?
        incident_data(models)
      end

      def incident_recorder_sex(sex)
        r = SEX[sex]
        r.present? ? r : sex
      end

      def perpetrators_sex(perpetrators=[])
        if perpetrators.present?
          gender_list = perpetrators.map{|p| p.perpetrator_sex}
          #TODO INVESTIGATE!!!!
          male_count = gender_list.count {|g| g.try(:downcase) == 'male'}
          female_count = gender_list.count {|g| g.try(:downcase) == 'female'}

          if male_count > 0
            (female_count > 0) ? I18n.t("exports.incident_recorder_xls.gender.both") : I18n.t("exports.incident_recorder_xls.gender.male")
          elsif female_count > 0
            I18n.t("exports.incident_recorder_xls.gender.female")
          end
        end
      end

      def age_group_or_age_type(age_group_count, age_type_count)
        if age_type_count > 0 && age_group_count <= 0
          'age_type'
        else
          'age_group'
        end
      end

      def age_group_and_type_count
        age_group_count = 0
        age_type_count = 0
        fs = FormSection.by_unique_id(key: 'alleged_perpetrator').first
        if fs.present?
          age_group_count = fs.fields.count{|f| f.name == 'age_group' and f.visible?}
          age_type_count = fs.fields.count{|f| f.name == 'age_type' and f.visible?}
        end
        return age_group_count, age_type_count
      end

      def alleged_perpetrator_header
        #Only calculate these once
        if @age_group_count < 0 || @age_type_count < 0
          @age_group_count, @age_type_count = age_group_and_type_count
        end

        case age_group_or_age_type(@age_group_count, @age_type_count)
          when 'age_type'
            I18n.t("exports.incident_recorder_xls.age_type.header")
          else
            I18n.t("exports.incident_recorder_xls.age_group.header")
        end
      end

      def incident_recorder_age(perpetrators)
        case age_group_or_age_type(@age_group_count, @age_type_count)
          when 'age_type'
            incident_recorder_age_type(perpetrators)
          else
            incident_recorder_age_group(perpetrators)
        end
      end

      def incident_recorder_age_group(perpetrators)
        age = perpetrators.first.try(:age_group)
        r = AGE_GROUP[age]
        r.present? ? r : age
      end

      def incident_recorder_age_type(perpetrators)
        if perpetrators.present?
          age_type_list = perpetrators.map{|p| p.age_type}
          adult_count = age_type_list.count {|at| at.try(:downcase) == 'adult'}
          minor_count = age_type_list.count {|at| at.try(:downcase) == 'minor'}
          unknown_count = age_type_list.count {|at| at.try(:downcase) == 'unknown'}

          if adult_count > 0
            (minor_count > 0) ? I18n.t("exports.incident_recorder_xls.age_type.both") : I18n.t("exports.incident_recorder_xls.age_type.adult")
          elsif minor_count > 0
            I18n.t("exports.incident_recorder_xls.age_type.minor")
          elsif unknown_count > 0
            I18n.t("exports.incident_recorder_xls.age_type.unknown")
          end
        end
      end

      def incident_recorder_service_referral_from(service_referral_from)
        r = SERVICE_REFERRED_FROM[service_referral_from]
        r.present? ? r : service_referral_from
      end

      def incident_recorder_service_referral(service)
        r = SERVICE_REFERRAL[service]
        r.present? ? r : service
      end

      def primary_alleged_perpetrator(model)
        alleged_perpetrator = model.try(:alleged_perpetrator)
        return [] if alleged_perpetrator.blank?
        alleged_perpetrator.select{|ap| ap.try(:primary_perpetrator) == "Primary"}
      end
      memoize :primary_alleged_perpetrator

      def all_alleged_perpetrators(model)
        alleged_perpetrators = model.try(:alleged_perpetrators)
        alleged_perpetrators.present? ? alleged_perpetrators : []
      end

      def location_from_hierarchy(location_name, types)
        location = Location.find_types_in_hierarchy(location_name, types)
        location ? location.placename : ""
      end

      def props
         ##### ADMINISTRATIVE INFORMATION #####
         #TODO - discuss with Pavel to see if this needs to change per SL-542
         #TODO - i18n - need translations for all of these hash keys / column headings
        {
          I18n.t('exports.incident_recorder_xls.headers.incident_id') => "incidentid_ir",
          I18n.t('exports.incident_recorder_xls.headers.survivor_code') => "survivor_code",
          I18n.t('exports.incident_recorder_xls.headers.case_manager_code') => ->(model) do
            caseworker_code = @caseworker_code[model.owned_by]
            if caseworker_code.blank?
              caseworker_code = model.try(:owner).try(:code)
            end
            #Collect information to the "Menu Data" sheet
            @caseworker_code[caseworker_code] = caseworker_code if caseworker_code.present?
            caseworker_code
          end,
          I18n.t('exports.incident_recorder_xls.headers.date_of_interview') => "date_of_first_report",
          I18n.t('exports.incident_recorder_xls.headers.date_of_incident') => "incident_date",
          I18n.t('exports.incident_recorder_xls.headers.date_of_birth') => "date_of_birth",
          I18n.t('exports.incident_recorder_xls.headers.sex') => ->(model) do
            #Need to convert 'Female' to 'F' and 'Male' to 'M' because
            #the spreadsheet is expecting those values.
            incident_recorder_sex(model.try(:sex))
          end,
          #NOTE: 'H' is hidden and protected in the spreadsheet.
          I18n.t('exports.incident_recorder_xls.headers.ethnicity') => "ethnicity",
          I18n.t('exports.incident_recorder_xls.headers.country_of_origin') => "country_of_origin",
          I18n.t('exports.incident_recorder_xls.headers.marital_status') => "maritial_status",
          I18n.t('exports.incident_recorder_xls.headers.displacement_status') => "displacement_status",
          I18n.t('exports.incident_recorder_xls.headers.disability_type') => "disability_type",
          I18n.t('exports.incident_recorder_xls.headers.unaccompanied_separated_status') => "unaccompanied_separated_status",
          I18n.t('exports.incident_recorder_xls.headers.stage_of_displacement') => "displacement_incident",
          I18n.t('exports.incident_recorder_xls.headers.time_of_day') => ->(model) do
            incident_timeofday = model.try(:incident_timeofday)
            incident_timeofday.present? ? incident_timeofday.split("(").first.strip : nil
          end,
          I18n.t('exports.incident_recorder_xls.headers.location') => "incident_location_type",
          I18n.t('exports.incident_recorder_xls.headers.county') => ->(model) do
            county_name = location_from_hierarchy(model.try(:incident_location), ['county'])
            #Collect information to the "2. Menu Data sheet."
            @counties[county_name] = county_name if county_name.present?
            county_name
          end,
          I18n.t('exports.incident_recorder_xls.headers.district') => ->(model) do
            district_name = location_from_hierarchy(model.try(:incident_location), ['province'])
            #Collect information to the "2. Menu Data sheet."
            @districts[district_name] = district_name if district_name.present?
            district_name
          end,
          I18n.t('exports.incident_recorder_xls.headers.camp_town') => "incident_camp_town",
          I18n.t('exports.incident_recorder_xls.headers.gbv_type') => "gbv_sexual_violence_type",
          I18n.t('exports.incident_recorder_xls.headers.harmful_traditional_practice') => "harmful_traditional_practice",
          I18n.t('exports.incident_recorder_xls.headers.goods_money_exchanged') => "goods_money_exchanged",
          I18n.t('exports.incident_recorder_xls.headers.abduction_type') => "abduction_status_time_of_incident",
          I18n.t('exports.incident_recorder_xls.headers.previously_reported') => ->(model) do
            REPORTED_ELSEWHERE[model.try(:gbv_reported_elsewhere)]
          end,
          I18n.t('exports.incident_recorder_xls.headers.gbv_previous_incidents') => "gbv_previous_incidents",
          ##### ALLEGED PERPETRATOR INFORMATION #####
          I18n.t('exports.incident_recorder_xls.headers.number_primary_perpetrators') => ->(model) do
            calculated = all_alleged_perpetrators(model).size
            from_ir = model.try(:number_of_individual_perpetrators_from_ir)
            if from_ir.present?
              (calculated.present? && calculated > 1) ? calculated : from_ir
            else
              calculated
            end
          end,
          I18n.t('exports.incident_recorder_xls.headers.perpetrator.sex') => ->(model) do
            perpetrators_sex(all_alleged_perpetrators(model))
          end,
          I18n.t('exports.incident_recorder_xls.headers.perpetrator.former') => ->(model) do
            former_perpetrators = primary_alleged_perpetrator(model).map{|ap| ap.try(:former_perpetrator)}.select{|is_ap| is_ap != nil}
            #TODO: FIX!!!!!!!
            if former_perpetrators.include? 'Yes'
              I18n.t("gbv_report.yes")
            elsif former_perpetrators.all? { |is_fp| is_fp == 'No' }
              I18n.t("gbv_report.no")
            end
          end,
          #TODO: FIX!!!!
          alleged_perpetrator_header => ->(model) do
            incident_recorder_age(all_alleged_perpetrators(model))
          end,
          I18n.t('exports.incident_recorder_xls.headers.perpetrator.relationship') => ->(model) do
            primary_alleged_perpetrator(model).first.try(:perpetrator_relationship)
          end,
          I18n.t('exports.incident_recorder_xls.headers.perpetrator.occupation') => ->(model) do
            primary_alleged_perpetrator(model).first.try(:perpetrator_occupation)
          end,
          ##### REFERRAL PATHWAY DATA #####
          I18n.t('exports.incident_recorder_xls.headers.service.referred_from') => ->(model) do
            services = model.try(:service_referred_from)
            if services.present?
              if services.is_a?(Array)
                services.map{|srf| incident_recorder_service_referral_from(srf) }.join(" & ")
              else
                incident_recorder_service_referral_from(services)
              end
            end
          end,
          I18n.t('exports.incident_recorder_xls.headers.service.safehouse_referral') => ->(model) do
            incident_recorder_service_referral(model.try(:service_safehouse_referral))
          end,
          I18n.t('exports.incident_recorder_xls.headers.service.medical_referral') => ->(model) do
            service_value = model.health_medical_referral_subform_section.try(:first).try(:service_medical_referral)
            incident_recorder_service_referral(service_value) if service_value.present?
          end,
          I18n.t('exports.incident_recorder_xls.headers.service.psycho_referral') => ->(model) do
            service_value = model.psychosocial_counseling_services_subform_section.try(:first).try(:service_psycho_referral)
            incident_recorder_service_referral(service_value) if service_value.present?
          end,
          I18n.t('exports.incident_recorder_xls.headers.service.wants_legal_action') => ->(model) do
            legal_counseling = model.try(:legal_assistance_services_subform_section)
            if legal_counseling.present?
              legal_actions = legal_counseling.
                  map{|l| l.try(:pursue_legal_action)}
              if legal_actions.include? true
                'Yes'
              elsif legal_actions.include? false
                'No'
              elsif legal_actions.include? nil
                'Undecided at time of report'
              end
            end
          end,
          I18n.t('exports.incident_recorder_xls.headers.service.legal_referral') => ->(model) do
            service_value = model.legal_assistance_services_subform_section.try(:first).try(:service_legal_referral)
            incident_recorder_service_referral(service_value) if service_value.present?
          end,
          I18n.t('exports.incident_recorder_xls.headers.service.police_referral') => ->(model) do
            service_value = model.police_or_other_type_of_security_services_subform_section.try(:first).try(:service_police_referral)
            incident_recorder_service_referral(service_value) if service_value.present?
          end,
          I18n.t('exports.incident_recorder_xls.headers.service.livelihoods_referral') => ->(model) do
            service_value = model.livelihoods_services_subform_section.try(:first).try(:service_livelihoods_referral)
            incident_recorder_service_referral(service_value) if service_value.present?
          end,
          ##### ADMINISTRATION 2 #####
          I18n.t('exports.incident_recorder_xls.headers.service.protection_referral') => ->(model) do
            service_value = model.child_protection_services_subform_section.try(:first).try(:service_protection_referral)
            incident_recorder_service_referral(service_value) if service_value.present?
          end,
          I18n.t('exports.incident_recorder_xls.headers.consent') => "consent_reporting",
          I18n.t('exports.incident_recorder_xls.headers.agency_code') => ->(model) do
            model.owner.try(:agency).try(:agency_code)
          end
        }
      end

      def incident_data(models)
        #Sheet 0 is the "Incident Data".
        @props = props
        incident_data_header
        models.each do |model|
          j = 0
          @props.each do |name, prop|
            if prop.present?
              if prop.is_a?(Proc)
                value = prop.call(model)
              else
                value = model.try(prop.to_sym)
              end
              if value.is_a?(Date)
                formatted_value = I18n.l(value)
              elsif value.is_a?(String)
                formatted_value = Exporters::IncidentRecorderExporter.translate_value(prop, value)
              else
                formatted_value = value
              end
              @data_worksheet.write(@row_data, j, formatted_value) unless formatted_value.nil?
            end
            j += 1
          end
          @row_data += 1
        end
      end

      def incident_menu
        #Sheet 1 is the "Menu Data".
        incident_menu_header
        #lookups.
        #In this sheet only 50 rows are editable for lookups.
        menus = [
          {:cell_index => 0, :values => @caseworker_code.values[0..49]},
          {:cell_index => 1, :values => @locations.values[0..49]},
          {:cell_index => 2, :values => @counties.values[0..49]},
          {:cell_index => 3, :values => @districts.values[0..49]},
          {:cell_index => 4, :values => @camps.values[0..49]}
        ]

        menus.each do |menu|
          #Sheet data start at row 1 (based 0 index).
          i = 1
          #Cell where the data should be push.
          j = menu[:cell_index]
          menu[:values].each do |value|
            @menu_worksheet.write(i, j, value)
            i += 1
          end
        end
      end

      def set_column_widths(worksheet, header)
        header.each_with_index do |v, i|
          worksheet.set_column(i, i, v.length+5)
        end
      end

    end
  end
end
