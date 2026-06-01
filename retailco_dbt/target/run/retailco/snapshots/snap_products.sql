
      update "warehouse"."snapshots"."snap_products"
    set dbt_valid_to = DBT_INTERNAL_SOURCE.dbt_valid_to
    from "snap_products__dbt_tmp223724676319" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_scd_id::text = "warehouse"."snapshots"."snap_products".dbt_scd_id::text
      and DBT_INTERNAL_SOURCE.dbt_change_type::text in ('update'::text, 'delete'::text)
      
        and "warehouse"."snapshots"."snap_products".dbt_valid_to is null;
      


    insert into "warehouse"."snapshots"."snap_products" ("product_id", "sku", "product_name", "category", "sub_category", "brand", "supplier", "cost_price", "selling_price", "is_deleted", "effective_from", "created_at", "updated_at", "dbt_updated_at", "dbt_valid_from", "dbt_valid_to", "dbt_scd_id")
    select DBT_INTERNAL_SOURCE."product_id",DBT_INTERNAL_SOURCE."sku",DBT_INTERNAL_SOURCE."product_name",DBT_INTERNAL_SOURCE."category",DBT_INTERNAL_SOURCE."sub_category",DBT_INTERNAL_SOURCE."brand",DBT_INTERNAL_SOURCE."supplier",DBT_INTERNAL_SOURCE."cost_price",DBT_INTERNAL_SOURCE."selling_price",DBT_INTERNAL_SOURCE."is_deleted",DBT_INTERNAL_SOURCE."effective_from",DBT_INTERNAL_SOURCE."created_at",DBT_INTERNAL_SOURCE."updated_at",DBT_INTERNAL_SOURCE."dbt_updated_at",DBT_INTERNAL_SOURCE."dbt_valid_from",DBT_INTERNAL_SOURCE."dbt_valid_to",DBT_INTERNAL_SOURCE."dbt_scd_id"
    from "snap_products__dbt_tmp223724676319" as DBT_INTERNAL_SOURCE
    where DBT_INTERNAL_SOURCE.dbt_change_type::text = 'insert'::text;

  