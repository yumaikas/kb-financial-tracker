Sequel.migration do
	up do 
		alter_table(:transactions)  do
			add_column :month_year, String
		end

		create_table :settings do
			primary_key :setting_id
			String :key, unique: true, null: false
			String :value, null: false
		end

		DB[:transactions].update(month_year: Date.today.strftime("%Y-%m"))
		DB[:settings].insert(key: "Current_Month", value: Date.today.strftime("%Y-%m"))
		DB[:settings].insert(key: "Target_Date", value: Date.today.strftime("%Y-%m-%d"))
	end

	down do
		alter_table(:transactions)  do
			drop_column :month_year
		end
		drop_table :settings
	end
end