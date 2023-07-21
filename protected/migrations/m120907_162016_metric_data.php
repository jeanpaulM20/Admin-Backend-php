<?php
class m120907_162016_metric_data extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_metric_data')) {
        	$this->createTable('tbl_metric_data', array(
				'id' => 'pk',
				'timestamp' => 'datetime NULL',
				'value' => 'float NULL',
				'sort' => 'integer NULL DEFAULT \'0\'',
				'metric_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('sort', 'tbl_metric_data', 'sort', false);				
			$this->createIndex('metric_id', 'tbl_metric_data', 'metric_id', false);				

			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_metric_data')) {
        	$this->dropTable('tbl_metric_data');
        }
    }
}