create procedure goinfo."proc_korelacija_asim"(
    in in_query long varchar
)
begin
    /*
				procedura izračuna eta squared matriko za vse kombinacije
				kategoričnih in numeričnih spremenljivk. eta squared je asimetrična mera
				parametri:
				-in_query: poizvedba, ki vrne podatke 
				začetek: 13.10.2025
    */
    declare sql_string long varchar;
    declare pivot_stolp long varchar;
    declare grand_mean double;
    declare ss_total double;
    declare ss_between double;
    declare eta_sq double;
    
    declare local temporary table #cat_stolp(
        ime long varchar,
        stolp_v_red int primary key
    ) not transactional;
    
    declare local temporary table #num_stolp(
        ime long varchar,
        stolp_v_red int primary key
    ) not transactional;
    
    declare local temporary table #eta_vrednosti(
        row_var long varchar,
        col_var long varchar,
        eta_vrednost double
    ) not transactional;
    
    declare local temporary table #group_stats(
        cat_value long varchar,
        group_mean double,
        group_count int
    ) not transactional;
    
    begin
        drop table goinfo.korelacija_rezultat;
    exception when others then
    end;
    
    execute immediate 'select * into #data_vir from (' || in_query || ') as vir_query';
    insert into #cat_stolp (ime, stolp_v_red)
    select
        name,
        row_number() over (order by name) as stolp_v_red
    from sa_describe_query('select * from #data_vir')
    where domain_name in (
        'char', 'varchar', 'long varchar', 'nchar', 'nvarchar','long nvarchar'
    );
    insert into #num_stolp (ime, stolp_v_red)
    select
        name,
        row_number() over (order by name) as stolp_v_red
    from sa_describe_query('select * from #data_vir')
    where domain_name in (
        'integer', 'smallint', 'bigint', 'tinyint',
        'unsigned integer', 'unsigned smallint', 'unsigned bigint',
        'decimal', 'numeric', 'float', 'real', 'double'
    );

    if not exists(select 1 from #cat_stolp) or not exists(select 1 from #num_stolp) then
        create table goinfo.korelacija_rezultat(spremenljivka varchar(255) null);
        drop table #num_stolp;
        drop table #cat_stolp;
        drop table #data_vir;
        return;
    end if;
    
    --cat->num
    for eta_loop as eta_cursor cursor for
        select c.ime as cat_col, n.ime as num_col
        from #cat_stolp as c, #num_stolp as n
    do
        delete from #group_stats;
        
        --skupinska statistika
        set sql_string = 
            'insert into #group_stats (cat_value, group_mean, group_count) ' ||
            'select "' || cat_col || '", avg("' || num_col || '"), count(*) ' ||
            'from #data_vir ' ||
            'where "' || cat_col || '" is not null and "' || num_col || '" is not null ' ||
            'group by "' || cat_col || '"';
        execute immediate sql_string;
        
        --mean
        set sql_string = 
            'select avg("' || num_col || '") into grand_mean ' ||
            'from #data_vir ' ||
            'where "' || cat_col || '" is not null and "' || num_col || '" is not null';
        execute immediate sql_string;
        
        --ss_total
        set sql_string = 
            'select sum(power("' || num_col || '" - ' || cast(grand_mean as varchar) || ', 2)) into ss_total ' ||
            'from #data_vir ' ||
            'where "' || cat_col || '" is not null and "' || num_col || '" is not null';
        execute immediate sql_string;
        
        --ss_between
        select sum(group_count * power(group_mean - grand_mean, 2)) into ss_between
        from #group_stats;
        
        --eta squared
        if ss_total is not null and ss_total > 0 and ss_between is not null then
            set eta_sq = ss_between / ss_total;
        else
            set eta_sq = 0;
        end if;
        
        insert into #eta_vrednosti (row_var, col_var, eta_vrednost)
        values (cat_col, num_col, eta_sq);
    end for;
    
    select list('max(case when col_var = ''' || ime || ''' then eta_vrednost end) as "' || ime || '"', ', ' order by stolp_v_red)
    into pivot_stolp
    from #num_stolp;
    
    set sql_string = 
        'select row_var as "spremenljivka", ' || pivot_stolp || ' ' ||
        'into goinfo.korelacija_rezultat ' ||
        'from #eta_vrednosti ' ||
        'group by row_var ' ||
        'order by (select stolp_v_red from #cat_stolp where ime = row_var)';
    
    execute immediate sql_string;
    
    drop table #cat_stolp;
    drop table #num_stolp;
    drop table #eta_vrednosti;
    drop table #group_stats;
    drop table #data_vir;
    
end
