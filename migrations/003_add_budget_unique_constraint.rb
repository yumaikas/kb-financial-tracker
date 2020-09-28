Sequel.migration do
	up do
		alter_table(:category_budgets) do
			add_unique_constraint [:category_id]
		end
	end
  down do
    drop_column :category_budgets, :category_id
  end
end