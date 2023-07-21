<?php
class m120907_162016_language extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_language')) {
        	$this->createTable('tbl_language', array(
				'id' => 'pk',
				'language' => 'string NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');

        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_language')) {
        	$this->dropTable('tbl_language');
        }
    }
}