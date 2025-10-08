create procedure goinfo."proc_korelacija"(
	in in_query long varchar,
	in in_method long varchar default 'PEARSON'
)
begin
	/*
		procedura izračuna korelacijsko matriko za vse numerične stolpce 
		ali cramer v za kategorične stolpce.
		
		parametri:
		-in_query: poizvedba, ki vrne podatke
		-in_method: 'PEARSON' (privzeto), 'SPEARMAN', ali 'CRAMER'
		
		začetek: 02.10.2025
		posodobljeno: 06.10.2025 -implementiran spearman
		posodobljeno: 08.10.2025 -matematično popravljen spearman
		posodobljeno: 08.10.2025 -dodan cramer v
	*/
	
	declare sql_string long varchar;
	declare pivot_stolp long varchar;
	declare source_table long varchar;
	declare col_prefix long varchar;
	declare rank_cols_inner long varchar;
	declare rank_cols_outer long varchar;
	
	declare local temporary table #num_stolp(
		ime long varchar,
		stolp_v_red int primary key
	) not transactional;
	
	declare local temporary table #cat_stolp(
		ime long varchar,
		stolp_v_red int primary key
	) not transactional;
	
	declare local temporary table #korelac(
		col1 long varchar,
		col2 long varchar,
		kore_vrednost double
	) not transactional;
	
	declare local temporary table #contingency(
		cat1_value long varchar,
		cat2_value long varchar,
		observed_freq int
	) not transactional;
	
	if UPPER(in_method) not in ('PEARSON', 'SPEARMAN', 'CRAMER') then
		raiserror 99999 'Neveljavna metoda. Uporabite PEARSON, SPEARMAN ali CRAMER.';
		return;
	end if;
	
	begin
		drop table goinfo.korelacija_rezultat;
	exception when others then
	end;
	
	execute immediate 'select * into #data_vir from (' || in_query || ') as vir_query';
	
	--cramer v za kategorične spremenljivke
	if UPPER(in_method) = 'CRAMER' then
		--identificiraj kategorične stolpce
		insert into #cat_stolp (ime, stolp_v_red)
		select
			name,
			ROW_NUMBER() over (order by name) as stolp_v_red
		from sa_describe_query('select * from #data_vir')
		where domain_name in (
			'char', 'varchar', 'long varchar', 'nchar', 'nvarchar'
		);
		
		--izračunaj cramer v za vsak par (gornji trikotnik)
		for cramer_loop as cramer_cursor cursor for
			select x.ime as col1, y.ime as col2
			from #cat_stolp as x, #cat_stolp as y
			where x.stolp_v_red < y.stolp_v_red
		do
			delete from #contingency;
			
			--ustvari kontigenčno tabelo
			set sql_string = 
				'insert into #contingency (cat1_value, cat2_value, observed_freq) ' ||
				'select "' || col1 || '", "' || col2 || '", COUNT(*) ' ||
				'from #data_vir ' ||
				'where "' || col1 || '" is not null and "' || col2 || '" is not null ' ||
				'group by "' || col1 || '", "' || col2 || '"';
			execute immediate sql_string;
			
			--izračunaj cramer v
			begin
				declare chi_square double;
				declare n_total int;
				declare n_rows int;
				declare n_cols int;
				declare cramers_v double;
				select SUM(observed_freq) into n_total from #contingency;
				select COUNT(distinct cat1_value) into n_rows from #contingency;
				select COUNT(distinct cat2_value) into n_cols from #contingency;
				
				--izračun chisquare statistike
				select 
					SUM(POWER(observed_freq - expected_freq, 2) / expected_freq)
				into chi_square
				from (
					select 
						c.observed_freq,
						(r.row_total * col.col_total * 1.0) / n_total as expected_freq
					from #contingency c
					join (
						select cat1_value, SUM(observed_freq) as row_total
						from #contingency
						group by cat1_value
					) r on c.cat1_value = r.cat1_value
					join (
						select cat2_value, SUM(observed_freq) as col_total
						from #contingency
						group by cat2_value
					) col on c.cat2_value = col.cat2_value
				) chi_calc
				where expected_freq > 0;
				
				--izračun cramer v: V = sqrt(χ² / (n * min(r-1, c-1)))
				if n_total > 0 and chi_square is not null and (case when n_rows < n_cols then n_rows else n_cols end - 1) > 0 then
					set cramers_v = SQRT(chi_square / (n_total * (case when n_rows < n_cols then n_rows else n_cols end - 1)));
				else
					set cramers_v = 0;
				end if;
				insert into #korelac (col1, col2, kore_vrednost)
				values (col1, col2, cramers_v);
			end;
		end for;
		insert into #korelac (col1, col2, kore_vrednost) 
		select col2, col1, kore_vrednost from #korelac;
		insert into #korelac (col1, col2, kore_vrednost) 
		select ime, ime, 1 from #cat_stolp;
		
		--pivot matrika za prikaz
		select LIST('max(case when col2 = ''' || ime || ''' then kore_vrednost end) as "' || ime || '"', ', ' order by ime)
		into pivot_stolp
		from #cat_stolp;
		
		set sql_string = 
			'select col1 as "Spremenljivka", ' || pivot_stolp || ' ' ||
			'into goinfo.korelacija_rezultat ' ||
			'from #korelac ' ||
			'group by col1 ' ||
			'order by (select stolp_v_red from #cat_stolp where ime = col1)';
		
		execute immediate sql_string;
		
		drop table #cat_stolp;
		drop table #contingency;
		
	else
		--numerične (pearson/spearman)
		insert into #num_stolp (ime, stolp_v_red)
		select
			name,
			ROW_NUMBER() over (order by name) as stolp_v_red
		from sa_describe_query('select * from #data_vir')
		where domain_name in (
			'integer', 'smallint', 'bigint', 'tinyint',
			'unsigned integer', 'unsigned smallint', 'unsigned bigint',
			'decimal', 'numeric', 'float', 'real', 'double'
		);
		
		--spearman rangirani podatki
		if UPPER(in_method) = 'SPEARMAN' then
			select list('row_number() over (order by "' || ime || '") as "rn_' || ime || '"', ', ') 
			into rank_cols_inner
			from #num_stolp;
			
			select list(
				'(min("rn_' || ime || '") over (partition by "' || ime || '") + ' ||
				'max("rn_' || ime || '") over (partition by "' || ime || '")) / 2.0 as "rank_' || ime || '"', 
				', '
			)
			into rank_cols_outer
			from #num_stolp;
			
			set sql_string = '
			select ' || rank_cols_outer || '
			into #ranked_data
			from (
				select *, ' || rank_cols_inner || '
				from #data_vir
			) as subquery';
			
			execute immediate sql_string;
			set source_table = '#ranked_data';
			set col_prefix = 'rank_';
		else
			--pearson uporablja originalne podatke
			set source_table = '#data_vir';
			set col_prefix = '';
		end if;
		
		--gornji trikotnik
		for korelac_loop as korelac_cursor cursor for
			select x.ime as col1, y.ime as col2
			from #num_stolp as x, #num_stolp as y
			where x.stolp_v_red < y.stolp_v_red
		do
			set sql_string = 
				'insert into #korelac (col1, col2, kore_vrednost) ' ||
				'select ''' || col1 || ''', ''' || col2 || ''', ' ||
				'corr("' || col_prefix || col1 || '", "' || col_prefix || col2 || '") ' ||
				'from ' || source_table;
			execute immediate sql_string;
		end for;
		
		--simetrična kopija
		insert into #korelac (col1, col2, kore_vrednost) 
		select col2, col1, kore_vrednost from #korelac;
		
		--diagonala=1
		insert into #korelac (col1, col2, kore_vrednost) 
		select ime, ime, 1 from #num_stolp;
		
		--pivot matrika
		select list('max(case when col2 = ''' || ime || ''' then kore_vrednost end) as "' || ime || '"', ', ' order by ime)
		into pivot_stolp
		from #num_stolp;
		
		--sestavljen pivot
		set sql_string = 
			'select col1 as "Spremenljivka", ' || pivot_stolp || ' ' ||
			'into goinfo.korelacija_rezultat ' ||
			'from #korelac ' ||
			'group by col1 ' ||
			'order by (select stolp_v_red from #num_stolp where ime = col1)';
		
		execute immediate sql_string;
		
		drop table #num_stolp;
		
		begin
			drop table #ranked_data;
		exception when others then
		end;
	end if;
	drop table #korelac;
	drop table #data_vir;
	
end



call goinfo.proc_korelacija_heatmap('SELECT poda,podb,podc,podd FROM #T5', 'N', 'SPEARMAN');
select * from dis_temp
