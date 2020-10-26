Sequel.migration do
	up do
		create_table :accounts do
			primary_key :account_id
			String :name, null: false
			BigDecimal :amount, null: false
		end

		create_table :account_allocation do
			primary_key :allocation_id
			foreign_key :account_id, :accounts
			String :description, null: false
			BigDecimal :amount, null: false
		end
	end

	down do
		drop_table(:account_allocation)
		drop_table(:accounts)
	end
end