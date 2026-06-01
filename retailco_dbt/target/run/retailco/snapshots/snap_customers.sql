
      update "warehouse"."snapshots"."snap_customers"
    set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to
    from "snap_customers__dbt_tmp223724668159" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_scd_id::text = "warehouse"."snapshots"."snap_customers".dbt_scd_id::text
      and DBT_INTERNAL_SOURCE.dbt_change_type::text in ('update'::text, 'delete'::text)
      
        and "warehouse"."snapshots"."snap_customers".dbt_valid_to is null;
      


    insert into "warehouse"."snapshots"."snap_customers" ("customer_id", "first_name", "last_name", "email", "phone", "segment", "tier", "address", "city", "state", "is_deleted", "effective_from", "registered_at", "created_at", "updated_at", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to", "dbt_scd_id")
    select DBT_INTERNAL_SOURCE."customer_id",DBT_INTERNAL_SOURCE."first_name",DBT_INTERNAL_SOURCE."last_name",DBT_INTERNAL_SOURCE."email",DBT_INTERNAL_SOURCE."phone",DBT_INTERNAL_SOURCE."segment",DBT_INTERNAL_SOURCE."tier",DBT_INTERNAL_SOURCE."address",DBT_INTERNAL_SOURCE."city",DBT_INTERNAL_SOURCE."state",DBT_INTERNAL_SOURCE."is_deleted",DBT_INTERNAL_SOURCE."effective_from",DBT_INTERNAL_SOURCE."registered_at",DBT_INTERNAL_SOURCE."created_at",DBT_INTERNAL_SOURCE."updated_at",DBT_INTERNAL_SOURCE."dbt_updated_at",DBT_INTERNAL_SOURCE."dbt_valid_from",DBT_INTERNAL_SOURCE."dbt_valid_to",DBT_INTERNAL_SOURCE."dbt_scd_id"
    from "snap_customers__dbt_tmp223724668159" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_change_type::text = 'insert'::text;

  