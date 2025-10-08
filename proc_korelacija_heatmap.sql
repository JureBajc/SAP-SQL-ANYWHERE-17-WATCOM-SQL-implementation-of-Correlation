create PROCEDURE goinfo."proc_korelacija_heatmap"(
	in in_query long varchar,
	in in_add_colors varchar(1) default 'Y'
)
begin
	/*
		datum: 03.10.2025
	*/
	
	declare sql_string long varchar;
	
	declare local temporary table #osi (
		ime varchar(255) primary key,
		indeks integer) not transactional;

	declare local temporary table #long_format (
		y_ime varchar(255),
		x_ime varchar(255),
		vrednost double) not transactional;
	CALL goinfo.proc_korelacija(in_query);

	DELETE FROM dis_temp;
	insert into #osi (ime, indeks)
	select
		Spremenljivka as ime,
		row_number() over (order by Spremenljivka) - 1 as indeks
	from goinfo.korelacija_rezultat;
	
	for col_loop as c CURSOR FOR
		select ime from #osi order by indeks
	do
		set sql_string =
			'insert into #long_format (y_ime, x_ime, vrednost) ' ||
			'select Spremenljivka, ''' || ime || ''', "' || ime || '" ' ||
			'from goinfo.korelacija_rezultat';
		execute immediate sql_string;
	end for;
	
	insert into dis_temp(
		Kat1,
		Serija1,
		Vrednost,
		Naz_Kat1,
		Dodatno,
		BarvaKat1
	)
	select
		y.indeks,
		x.indeks,
		L.vrednost,
		y.ime || ' vs ' || x.ime as Naz_Kat1,
		'[' || x.indeks || ',' || y.indeks || ',' || 
			ROUND(L.vrednost, 4) || ',"' || y.ime || ' vs ' || x.ime || '"]' as Dodatno,
		case 
			when in_add_colors = 'Y' then
				case 
					when ABS(L.vrednost) >= 0.8 then 'a50026'
					when ABS(L.vrednost) >= 0.6 then 'f46d43'
					when ABS(L.vrednost) >= 0.4 then 'fdae61'
					when ABS(L.vrednost) >= 0.2 then 'abd9e9'
					else 'ffffbf'
				end
			else null
		end as BarvaKat1
	from #long_format as L
	join #osi as x on L.x_ime = x.ime
	join #osi as y on L.y_ime = y.ime;
	
	insert into dis_temp(Kat2, Serija2, Vrednost)
	select
		'AXIS_LABEL' as category,
		ime as label_name,
		indeks as order_index
	from #osi
	order by indeks;
	
	drop table #osi;
	drop table #long_format;
	
end