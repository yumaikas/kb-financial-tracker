Sequel.migration do
	up do
		create_join_table(transaction_id: :transactions, category_id: :categories)
	end

	down do
		drop_table(:categories_transactions)
	end
end