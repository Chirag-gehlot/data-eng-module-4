with trip_union as (
    select * from {{ref("int_trips_union")}}
),

vendors as (
    select 
        distinct vendorid,
        {{get_vendor_data("vendorid")}} as vendor_name
    from trip_union
)

select * from vendors