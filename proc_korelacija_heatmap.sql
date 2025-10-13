create procedure goinfo."proc_korelacija_heatmap"(
    in in_query long varchar,
    in in_add_colors varchar(1) default 'y',
    in in_method varchar(10) default 'pearson'
)
begin
    /*
        datum: 03.10.2025
        
        posodobljeno: 06.10.2025 -implementiran spearman
        posodobljeno: 08.10.2025 -dodan cramer v
        posodobljeno: 10.10.2025 -dodan eta squared podpora
        posodobljeno: 13.10.2025 -router za sim/asim metode
    */
    declare sql_string long varchar;
    declare local temporary table #osi (
        ime varchar(255) primary key,
        indeks integer) not transactional;
    declare local temporary table #long_format (
        y_ime varchar(255),
        x_ime varchar(255),
        vrednost double) not transactional;
    
    --router sim v asim
    if in_method in ('pearson', 'spearman', 'cramer') then
        --sim metode
        call goinfo.proc_korelacija(in_query, in_method);
    elseif in_method = 'eta' then
        --asim metoda
        call goinfo.proc_korelacija_asim(in_query);
    else
        raiserror 99999 'neveljavna metoda. uporabite pearson, spearman, cramer ali eta.';
        return;
    end if;
    
    delete from dis_temp;
    insert into #osi (ime)
    select spremenljivka from goinfo.korelacija_rezultat where spremenljivka is not null
    union
    select name from sa_describe_query('select * from goinfo.korelacija_rezultat') where name <> 'spremenljivka';
    
    update #osi set indeks = r.rn - 1
    from #osi join (
        select ime, row_number() over (order by ime) as rn from #osi
    ) as r on #osi.ime = r.ime;
    for col_loop as c cursor for
        select name as ime from sa_describe_query('select * from goinfo.korelacija_rezultat') 
        where name <> 'spremenljivka'
    do
        set sql_string =
            'insert into #long_format (y_ime, x_ime, vrednost) ' ||
            'select spremenljivka, ''' || ime || ''', "' || ime || '" ' ||
            'from goinfo.korelacija_rezultat';
        execute immediate sql_string;
    end for;
    
    insert into dis_temp(
        kat1,
        serija1,
        vrednost,
        naz_kat1,
        dodatno,
        barvakat1
    )
    select
        y.indeks,
        x.indeks,
        l.vrednost,
        y.ime || ' vs ' || x.ime as naz_kat1,
        '[' || x.indeks || ',' || y.indeks || ',' || 
            coalesce(cast(round(l.vrednost, 4) as varchar), 'null') || 
            ',"' || y.ime || ' vs ' || x.ime || '"]' as dodatno,
        case
            when l.vrednost is null then 'cccccc'
            when in_add_colors = 'y' and in_method = 'eta' then
                case 
                    when l.vrednost >= 0.5 then 'a50026'
                    when l.vrednost >= 0.3 then 'f46d43'
                    when l.vrednost >= 0.1 then 'fdae61'
                    else 'ffffbf'
                end
            when in_add_colors = 'y' then
                case 
                    when abs(l.vrednost) >= 0.8 then 'a50026'
                    when abs(l.vrednost) >= 0.6 then 'f46d43'
                    when abs(l.vrednost) >= 0.4 then 'fdae61'
                    when abs(l.vrednost) >= 0.2 then 'abd9e9'
                    else 'ffffbf'
                end
            else null
        end as barvakat1
    from #long_format as l
    join #osi as x on l.x_ime = x.ime
    join #osi as y on l.y_ime = y.ime;
    
    insert into dis_temp(kat2, serija2, vrednost)
    select
        'axis_label' as category,
        ime as label_name,
        indeks as order_index
    from #osi
    order by indeks;
    
    drop table #osi;
    drop table #long_format;
    
end
