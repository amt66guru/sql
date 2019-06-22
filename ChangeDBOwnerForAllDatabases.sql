/*
	Author: AM Taylor
	Date:	22 June 2019
	Desc:	Changes the owner of the database from the current owner to an new owner set by the value 
			in the @NewOwner variable.  If it comes across a database it can't write to it will stop
			and exit reporting the name of the database it couldn't write to. The exception to this 
			behaviour is read only databases which are excluded from the cursor.
*/

DECLARE @DbName sysname
DECLARE @SqlCmd nvarchar(1000)
DECLARE @OldOwner nvarchar(50)
DECLARE @NewOwner nvarchar(50) = 'sa'

 DROP TABLE IF EXISTS #RESULTS1
 DROP TABLE IF EXISTS #RESULTS2

-- Check if there are any databases that can't be written to and insert to temp table for report at end
SELECT 'Database owner not changed' as Col1,NAME as Col2, state_desc as Col3, CASE WHEN is_read_only = 1 THEN 'Read Only' END AS Col4 INTO #Results1 
FROM SYS.databases
WHERE state <> 0 OR is_read_only = 1

BEGIN TRY
DECLARE Amt_Cur  CURSOR FOR

SELECT name FROM sys.databases 
WHERE name NOT IN ('master','model','msdb','tempdb')
	AND is_read_only <>1 -- status not read only
	AND state = 0 -- status
	AND owner_sid <>0x01 -- not sa
ORDER BY name

	OPEN Amt_Cur
	FETCH NEXT FROM Amt_Cur INTO @DbName
	WHILE @@fetch_status <> -1 -- determines loop is continuing
	BEGIN 
		IF @@fetch_status <> -2 -- determines record is still available
		BEGIN  
			SET @OldOwner = (SELECT suser_sname(owner_sid) FROM sys.databases WHERE name = @DbName)
			SET @SqlCmd = N'ALTER AUTHORIZATION ON database::'+@DbName +' TO ' + @NewOwner
			EXEC (@SqlCmd)
			SET @newowner = (SELECT suser_sname(owner_sid) FROM sys.databases WHERE name = @DbName)
			--PRINT 'Changed '+@DbName+ ' owner from '+@OldOwner +' to '+ @NewOwner
			SELECT 'Database owner changed for' as Col1, @DbName as Col2,@OldOwner as Col3, @NewOwner as Col4 into #Results2 		
		END
	FETCH NEXT FROM Amt_Cur INTO @DbName
	END
	
END TRY
BEGIN CATCH
	-- Test whether the transaction is uncommittable and if it is rollback
	IF xact_state()<> 0 ROLLBACK ;
	PRINT 'Can''t change the owner of '+ @DbName
		
END CATCH

CLOSE Amt_Cur
DEALLOCATE Amt_Cur

-- Need to work on this so that it outputs a list of what it has done
IF OBJECT_ID('TEMPDB.#Results1') IS NOT NULL SELECT * FROM #Results1

IF OBJECT_ID('TEMPDB.#Results2') IS NOT NULL SELECT * FROM #Results2



