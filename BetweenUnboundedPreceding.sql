USE <database>;

with RunningTotals as 
(
	select myid,orderid,orderdate, val,
		sum(val) over(partition by custid
				order by orderdate, orderid
				rows between unbounded preceding
					and current row) as RunningTotal
	from myOrders
)
select *
from RunningTotals
where RunningTotal>1000.00;