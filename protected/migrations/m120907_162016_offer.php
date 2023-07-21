<?php
class m120907_162016_offer extends CDbMigration
{
    public function up()
    {
    	if (!$this->getDbConnection()->getSchema()->getTable('tbl_offer')) {
        	$this->createTable('tbl_offer', array(
				'id' => 'pk',
				'name' => 'string NULL',
				'group' => 'string NULL',
				'type' => 'string NULL',
				'teaser' => 'text NULL',
				'file' => 'string NULL',
				'price' => 'string NULL',
				'startdate' => 'date NULL',
				'enddate' => 'date NULL',
				'archive' => 'boolean NULL',
				'published' => 'boolean NULL',
				'language_rel' => 'integer NULL',
				'trainer_id' => 'integer NULL',
        	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
			$this->createIndex('trainer_id', 'tbl_offer', 'trainer_id', false);				

			
				if (!$this->getDbConnection()->getSchema()->getTable('tbl_offer_location')) {
	$this->createTable('tbl_offer_location', array(
		'offer_id' => 'integer NOT NULL',
		'location_id' => 'integer NOT NULL',
		'PRIMARY KEY (offer_id, location_id)',
	), 'ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

	        }

        
    }
 
    public function down()
    {
    	if ($this->getDbConnection()->getSchema()->getTable('tbl_offer')) {
        	$this->dropTable('tbl_offer');
        }
    }
}