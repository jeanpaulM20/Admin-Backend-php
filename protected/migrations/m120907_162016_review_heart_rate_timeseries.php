<?php
class m120907_162016_review_heart_rate_timeseries extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_review_heart_rate_timeseries')) {
        	$this->createTable('tbl_review_heart_rate_timeseries', array(
				'id' => 'pk',
				'timestamp' => 'datetime NULL',
				'value' => 'float NULL',
				'sort' => 'integer NULL DEFAULT \'0\'',
				'review_id' => 'integer NOT NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('sort', 'tbl_review_heart_rate_timeseries', 'sort', false);				
			$this->createIndex('review_id', 'tbl_review_heart_rate_timeseries', 'review_id', false);				

			
	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_review_heart_rate_timeseries')) {
        	$this->dropTable('tbl_review_heart_rate_timeseries');
        }
    }
}