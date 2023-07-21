<?php
class m120801_120000_service extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_service')) {
        	$this->createTable('tbl_service', array(
        		'id' => 'pk',
  				'model' => 'string NOT NULL',
  				'service_alias' => 'string NOT NULL',
				'title' => 'text',
  				'description' => 'text',
  				'service_params' => 'text',
  				'select_fields' => 'text',
  				'condition' => 'text',
  				'order' => 'text',
				'group' => 'text',
				'publish' => 'boolean DEFAULT 0',
				'sortOrder' => 'integer DEFAULT 0',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_service')) {
        	$this->dropTable('tbl_service');
        }
    }
}