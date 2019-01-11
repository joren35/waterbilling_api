--------Add new col to a table
--ALTER TABLE table_name
--ADD column_name datatype;

------- Change the data type of a col
--ALTER TABLE table_name
--ALTER COLUMN column_name datatype;

------- To delete Table
--ALTER TABLE Persons
--DROP COLUMN DateOfBirth;


create table "account"
(
	acc_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
	username text unique,
	firstname text,
	lastname text,
	password text,
	mobile_num text,
	admin_prev boolean,
	address text,
	activation_status boolean,
	activation_code text unique
);

create table "bills"
(
  bill_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  b_userID int REFERENCES account(acc_id) ON DELETE CASCADE,
  reading int,
  date_of_bill date NOT NULL DEFAULT CURRENT_DATE,
  due_date date,
  amount decimal(8,2),
  cubic_meters int,
  rate decimal(8,2),
  status text,
  newly_added boolean,
  arrears decimal(8,2)
);

create table "groups"
(
  g_id int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  g_name text,
  g_admin int REFERENCES account(acc_id) ON DELETE CASCADE
);

create or replace function user_credentials(in par_id text, out text, out text, out text, out BOOLEAN) returns setof record as
$$
   select firstname,lastname,mobile_num,admin_prev from "account" where acc_id::TEXT = par_id;
$$
 language 'sql';

create or replace function register(in par_username text, in par_password text,in par_mobile text,
									in par_regkey text) returns text as
$$
  declare
    loc_res text;
    loc_val text;
	  loc_status boolean;

  begin
    select into loc_val activation_code from account where activation_code = par_regkey;
	  select into loc_status activation_status from account where activation_code = par_regkey;
    if loc_val isnull then
      loc_res = 'Invalid Reg Code';
	  elsif loc_status is true then
	    loc_res = 'used';
    else
       update account set username = par_username, password = par_password, mobile_num = par_mobile,
	                        activation_status = True where activation_code = par_regkey;
       select into loc_res acc_id from account where username = par_username;
    end if;
      return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function register_admin(in par_username text, in par_firstname text, in par_lastname text, in par_password text,
                                    in par_mobile text,in par_admin_prev boolean,in par_g_name text,in par_address text) returns text as
$$
  declare
    loc_res text;
    loc_user int;

  begin
    insert into account(username,firstname,lastname,password,mobile_num,admin_prev,address) values
      (par_username,par_firstname,par_lastname, par_password, par_mobile, par_admin_prev,par_address);
    select into loc_user acc_id from account where username = par_username;
    insert into groups(g_name,g_admin) values(par_g_name,loc_user);
      loc_res = 'ok';
      return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function add_account(in par_firstname text, in par_lastname text,
                                    in par_address text,in par_act_code text,in par_reading int,
                                    in par_amount decimal, in par_rate decimal, in par_cmused int,
                                    in par_date date, in par_due date, in par_status text) returns text as
$$
  declare
    loc_res text;
    loc_user int;

  begin
    insert into account(firstname,lastname,admin_prev,address,activation_status, activation_code) values
      (par_firstname, par_lastname, false, par_address, false, par_act_code);
    select into loc_user acc_id from account where activation_code = par_act_code;
    insert into bills(b_userID,reading,date_of_bill,due_date,amount, cubic_meters,rate,status,newly_added) values
      (loc_user, par_reading, par_date, par_due, par_amount, par_cmused,par_rate,par_status,false);

    loc_res = 'ok';
    return loc_res;

  end;
$$
LANGUAGE plpgsql;

create or replace function login(in par_username text, in par_password text) returns text as
$$
  declare
    loc_user text;
    loc_res text;
  begin
     select into loc_user acc_id from account
       where username = par_username and password = par_password;

     if loc_user isnull then
       loc_res = 'Error';
     else
       loc_res = loc_user;
     end if;
     return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function username_validator(in par_username text) returns text as
$$
  declare
    loc_user text;
    loc_res text;
  begin
     select into loc_user username from account
       where username = par_username;

     if loc_user isnull then
       loc_res = 'ok';
     else
       loc_res = 'exist';
     end if;
     return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function key_validator(in par_key text) returns text as
$$
  declare
    loc_key text;
    loc_res text;
  begin
     select into loc_key activation_code from account
       where activation_code = par_key;

     if loc_key isnull then
       loc_res = 'ok';
     else
       loc_res = 'exist';
     end if;
     return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function get_bills(in par_id text,out int, out text, out text, out int, out numeric , out int, out text, out numeric) returns setof record as
$$
   SELECT bill_id,TO_CHAR(date_of_bill, 'mm/dd/yyyy'),TO_CHAR(due_date, 'mm/dd/yyyy'),reading, amount, cubic_meters, status, arrears from bills
   where b_userID::text = par_id and newly_added = false;
$$
 language 'sql';

create or replace function add_bill(in par_id int, in par_date date, in par_reading int, in par_rate decimal) returns text as
$$
  declare
    loc_res text;
    loc_prevbill int;
  begin
     select into loc_prevbill reading from bills
       where b_userid = par_id order by date_of_bill desc limit 1;

     if loc_prevbill isnull then
       insert into bills(b_userID,reading,date_of_bill,amount,cubic_meters)
       values (par_id,par_reading,par_date,0,0);
       loc_res = 'ok';
     else
       insert into bills(b_userID,reading,date_of_bill,due_date,amount,status,cubic_meters,rate)
       values (par_id,par_reading,par_date,par_date+15,(par_reading-loc_prevbill)*par_rate,'Unpaid',par_reading-loc_prevbill,par_rate);
       loc_res = 'ok';
     end if;
     return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function searchbill(in par_name text, out int, out TEXT, out text, out text) returns setof record as
  $$
    select acc_id, firstname, lastname, address from account where concat(firstname, ' ',lastname) ilike par_name and admin_prev = False;
  $$
   language 'sql';

create or replace function get_selected_date(in par_id text, out int, out text, out text, out decimal, out text, out int) returns setof record as
  $$
    select reading, TO_CHAR(date_of_bill, 'MonthDD, YYYY'),TO_CHAR(due_date, 'MonthDD, YYYY'), amount, status, cubic_meters from bills where date_of_bill = (select max(date_of_bill) from bills where b_userid::text = par_id);
  $$
language 'sql';

create or replace function activation_status(in par_boolean boolean, out text, out text) returns setof record as
  $$
  select concat(lastname, ', ', firstname), activation_code from account where activation_status = par_boolean and admin_prev = false
  $$
language 'sql';

create or replace function get_names(out int, out text, out text, out text, out int) returns setof record as
$$
   select acc_id, lastname, firstname, TO_CHAR(max(date_of_bill), 'mm/dd/yyyy'), max(reading) from account, bills where admin_prev = false and acc_id = b_userid
   group by acc_id;
$$
language 'sql';

create or replace function get_latestbill_user(in par_id text, out int, out text, out text, out numeric, out int, out text, out bigint, out numeric, out numeric, out text) returns setof record as
$$
   select reading, TO_CHAR(date_of_bill, 'MonthDD, YYYY'),TO_CHAR(due_date, 'MonthDD, YYYY'),
   amount, cubic_meters, status, used_byQuery2(par_id), used_byQuery1(par_id), used_byQuery1(par_id)+amount,
   case when used_byQuery2(par_id) > 2 then 'Disconnection' else 'Good' end
   from bills
   where date_of_bill = (select max(date_of_bill) from bills where b_userid::text = par_id and newly_added = false) and b_userid::text = par_id and newly_added = false
$$
language 'sql';

create or replace function used_byQuery1(in par_id text,out numeric) returns numeric as
$$
	select COALESCE (sum(amount),0.00)
	from bills
	where b_userid::text = par_id and
			date_of_bill < (select max(date_of_bill) from bills where b_userid::text = par_id and newly_added = false) and
			status like 'Unpaid' and newly_added = false
$$
language 'sql';

create or replace function used_byQuery2(in par_id text,out bigint) returns bigint as
$$
	select count(case when status like 'Unpaid' then 1 end) as Unpaid
	 from bills
	 where b_userid::text = par_id and newly_added = false
$$
language 'sql';


create or replace function viewpaid(in par_text text, out TEXT, out TEXT,  out text, out INT, out numeric) returns setof record as
$$
 select firstname, lastname, TO_CHAR(date_of_bill, 'mm/dd/yyyy'), reading, amount from account, bills where status = par_text and acc_id = b_userid and newly_added = false ;
$$
language 'sql';

create or replace function update_bill(in par_id text) returns void as
$$
  begin
    update bills set status = 'Paid' where bill_id::text = par_id;
  end
$$
  language plpgsql;

  create or replace function get_unpaid(out int, out text, out text, out decimal) returns setof record as
$$
   SELECT bill_id, TO_CHAR(date_of_bill, 'Month yyyy'), lastname::text ||', '|| firstname::text AS name, amount from bills, account
   where bills.b_userID = account.acc_id and bills.status ilike 'unpaid' and newly_added = false;
$$
language 'sql';

create or replace function send_sms(out text, out numeric, out text) returns setof record as
$$
	select acc_id, mobile_num, sum(amount), TO_CHAR(max(due_date), 'Monthdd, yyyy'),count(case when status like 'Unpaid' then 1 end) from account, bills
	where (status = 'Unpaid' and mobile_num is not null) and (b_userid = acc_id and newly_added = false)
	group by acc_id
$$
language 'sql';

create or replace function send_sms_date(in par_date date, out text, out text, out text, out numeric, out numeric) returns setof record as
$$
	select mobile_num, TO_CHAR(date_of_bill, 'Monthdd, yyyy') ,TO_CHAR(due_date, 'Monthdd, yyyy'), amount, COALESCE (arrears,0.00) from account, bills
	where status = 'Unpaid' and mobile_num is not null  and newly_added = false and date_of_bill = par_date
	and acc_id=b_userid
$$
language 'sql';

create or replace function selected_dates(out text) returns setof text as
$$
	select TO_CHAR(date_of_bill, 'Monthdd, yyyy') from bills
	group by date_of_bill
	order by date_of_bill
	desc
$$
language 'sql';

create or replace function new_billingdate(in par_date date, in par_rate numeric) returns text as
$$
  declare
    loc_res text;
	  r int;
  begin
	FOR r IN select acc_id from account where admin_prev = false
	LOOP
	insert into bills (b_userid, date_of_bill, status, rate, newly_added)
			VALUES (r, par_date, 'Unpaid', par_rate, true);
	END LOOP;
	loc_res = 'added';
    return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function new_dateSelector(in par_date date,out int, out text, out text,out text, out boolean, out int, out date) returns setof record as
$$
	select bill_id, lastname, firstname, address, newly_added, reading,
	(select date_of_bill as prev_bill from bills
	where date_of_bill < par_date
	order by date_of_bill desc
	limit 1)
	from account, bills
	where date_of_bill = par_date and acc_id = b_userid
$$
language 'sql';

create or replace function new_maxDate(out text) returns text as
$$
	select to_char(max(date_of_bill+25), 'yyyy-mm-dd') from bills
$$
language 'sql';

create or replace function new_addbill(in par_id int, in par_reading int) returns text as
$$
  declare
    loc_res text;
    loc_prevreading int;
	loc_date text;
	loc_rate decimal;
	loc_reading int;
	loc_arrears decimal;
  begin
	  select reading, to_char(date_of_bill, 'MonthDD, YYYY') into loc_reading, loc_date from bills, account
	  where date_of_bill < (select date_of_bill from bills where bill_id = par_id)
	  	    and b_userid = (select b_userid from bills where bill_id = par_id)
	  order by date_of_bill desc
	  limit 1;
	  select into loc_rate rate from bills where bill_id = par_id;
	  select into loc_arrears COALESCE (sum(amount),0.00) from bills where b_userid =
	  (select b_userid from bills where bill_id = par_id) and newly_added = false and status = 'Unpaid'
	  and date_of_bill < (select date_of_bill from bills where bill_id = par_id);


	IF loc_reading isnull THEN
  		loc_res = loc_date;
	ELSIF loc_reading > par_reading then
		loc_res = 'less';
	ELSE
  		update bills set
		reading = par_reading, due_date = (Now()::date + 15), amount = (par_reading-loc_reading)*loc_rate, cubic_meters = par_reading-loc_reading, newly_added = false,
		arrears = loc_arrears
		where bill_id = par_id and newly_added = true;
		loc_res='ok';
	END IF;
	return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function get_all_mobile(out text) returns setof text as
$$
	select mobile_num from account where activation_status = true and mobile_num is not null
$$
language 'sql';

create or replace function get_disconnection(out text, out text, out text, out numeric, out bigint) returns setof record as
$$
	select lastname, firstname, address, sum(amount), count(status) from account, bills
	where b_userid = acc_id and status = 'Unpaid' and newly_added = false
	group by acc_id
	having count(case when status = 'Unpaid' then 1 end) >= 3
$$
language 'sql';


create or replace function edit_acc(in par_id int, in par_lastname text, in par_firstname text, in par_password text, in par_mobile_num text) returns text as
$$
  declare
    loc_res text;
  begin
    update account set firstname=par_firstname, lastname=par_lastname, password=par_password, mobile_num=par_mobile_num
    where acc_id=par_id;
    loc_res = 'ok';
    return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function edit_name(in par_id int, in par_firstname text, in par_lastname text) returns text as
$$
  declare
    loc_res text;
  begin
	update account set firstname = par_firstname, lastname = par_lastname where acc_id = par_id;
	loc_res = 'ok';
    return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function edit_mobile(in par_id int, in par_mobile text) returns text as
$$
  declare
    loc_res text;
  begin
	update account set mobile_num = par_mobile where acc_id = par_id;
	loc_res = 'ok';
    return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function edit_password(in par_id int, in par_password text) returns text as
$$
  declare
    loc_res text;
  begin
	update account set password = par_password where acc_id = par_id;
	loc_res = 'ok';
    return loc_res;
  end;
$$
LANGUAGE plpgsql;

create or replace function get_disconnection_sms(out text, out bigint, out numeric) returns setof record as
$$
	select mobile_num, count(status), sum(amount) from account, bills
	where b_userid = acc_id and status = 'Unpaid' and newly_added = false and admin_prev = false
		and activation_status = true and mobile_num is not null
	group by acc_id
	having count(case when status = 'Unpaid' then 1 end) >= 3
$$
language 'sql';

--select acc_id, lastname, firstname, TO_CHAR(max(date_of_bill), 'mm/dd/yyyy'), max(reading), count(case when status like 'Unpaid' then 1 end) as Unpaid
--from account, bills where admin_prev = false and acc_id = b_userid
--   group by acc_id;


--THIS SELECTS THE LATEST BILL INSERTED
-- select * from bills
-- where date_of_bill = (select max(date_of_bill) from bills)

-- select reading from bills
-- where b_userid = 1
-- order by date_of_bill desc
-- limit 1
