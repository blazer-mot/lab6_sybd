use master
backup database [User_Actions] 
to disk = 'D:\User_ActionsDYOO24_backup.bak' 
with format, 
medianame = 'SQL_Server_Backup', 
name = 'Полный бэкап базы данных';


use master;
go

create or alter procedure sp_RestoreDatabaseFromBackup
    @BackupFilePath nvarchar(512),
    @NewDBName nvarchar(128),
    @TargetFilesDir nvarchar(512)
as
begin
    set nocount on;

    if right(@TargetFilesDir, 1) <> '\' 
        set @TargetFilesDir = @TargetFilesDir + '\';

    create table #FileList (
        LogicalName nvarchar(128), PhysicalName nvarchar(260), Type char(1),
        FileGroupName nvarchar(128), Size numeric(20,0), MaxSize numeric(20,0),
        FileId bigint, CreateLSN numeric(25,0), DropLSN numeric(25,0),
        UniqueId uniqueidentifier, ReadOnlyLSN numeric(25,0), ReadWriteLSN numeric(25,0),
        BackupSizeInBytes bigint, SourceBlockSize int, FileGroupId int,
        LogGroupGuid uniqueidentifier, DifferentialBaseLsn numeric(25,0),
        DifferentialBaseGuid uniqueidentifier, IsReadOnly bit, IsPresent bit,
        TDEThumbprint varbinary(32), SnapshotUrl nvarchar(360)
    );

    declare @SqlList nvarchar(max) = 'RESTORE FILELISTONLY FROM DISK = ''' + @BackupFilePath + '''';
    insert into #FileList
    exec sp_executesql @SqlList;

    if not exists (select 1 from #FileList)
    begin
        raiserror('Не удалось прочитать логические имена файлов из указанного бэкапа.', 16, 1);
        drop table #FileList;
        return;
    end

    if exists (select name from sys.databases where name = @NewDBName)
    begin
        declare @SqlKill nvarchar(max) = 'ALTER DATABASE [' + @NewDBName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
        exec sp_executesql @SqlKill;
    end

    declare @LogicalName nvarchar(128);
    declare @Type char(1);
    declare @PhysicalName nvarchar(260);
    declare @MoveCommand nvarchar(max) = '';

    declare file_cursor cursor local fast_forward for
    select LogicalName, Type, PhysicalName from #FileList;

    open file_cursor;
    fetch next from file_cursor into @LogicalName, @Type, @PhysicalName;

    while @@fetch_status = 0
    begin
        declare @FileNameWithExt nvarchar(260) = reverse(substring(reverse(@PhysicalName), 1, charindex('\', reverse(@PhysicalName)) - 1));
        
        if @FileNameWithExt is null or @FileNameWithExt = ''
        begin
            declare @Ext nvarchar(5) = case when @Type = 'L' then '.ldf' else '.mdf' end;
            set @FileNameWithExt = @LogicalName + @Ext;
        end

        declare @TargetFilePath nvarchar(512) = @TargetFilesDir + @FileNameWithExt;

        set @MoveCommand = @MoveCommand + 'MOVE ''' + @LogicalName + ''' TO ''' + @TargetFilePath + ''', ';

        fetch next from file_cursor into @LogicalName, @Type, @PhysicalName;
    end

    close file_cursor;
    deallocate file_cursor;
    drop table #FileList;

    declare @SqlRestore nvarchar(max);
    set @SqlRestore = 'RESTORE DATABASE [' + @NewDBName + '] ' +
                      'FROM DISK = ''' + @BackupFilePath + ''' ' +
                      'WITH ' + @MoveCommand + 'REPLACE, STATS = 10;';
    
    begin try
        exec sp_executesql @SqlRestore;
        declare @SqlMultiUser nvarchar(max) = 'ALTER DATABASE [' + @NewDBName + '] SET MULTI_USER;';
        exec sp_executesql @SqlMultiUser;

        print 'База данных ' + @NewDBName + ' успешно восстановлена.';
    end try
    begin catch
        print 'Ошибка при восстановлении базы данных!';
        print error_message();
        
        if exists (select name from sys.databases where name = @NewDBName)
        begin
            set @SqlMultiUser = 'ALTER DATABASE [' + @NewDBName + '] SET MULTI_USER;';
            exec sp_executesql @SqlMultiUser;
        end
    end catch
end;
go

exec [master].[dbo].[sp_RestoreDatabaseFromBackup]
    @BackupFilePath = 'D:\User_ActionsDYOO24_backup.bak',
    @NewDBName = 'User_Actions_backupDB',
    @TargetFilesDir = 'D:\SQL_DATA\';